#!/bin/bash
# File: bacres.sh
# Author: John Brennan (R00104987)
# Date: 03-Mar-2013
# Description: This file performs backup and restore operations. See design.txt
#              for detailed overview of how this script was designed.
#

# Seed Values for Configuration Options
SOURCE_LOCATION=""                                          	# Location where files will be backed up from
BACKUP_LOCATION=""                                          	# Location of the backup folder
RESTORE_LOCATION=""												# Location where files will be restored to
PROJECT_NAME=""                                        			# The name of the project.
BACKUP_FILENAME="" 												# The name of the backup file. The name will be formatted with today's date and time, i.e. PROJECT_NAME_yyyymmdd_hhmmss.tar.gz
VERBOSE=0                                                   	# Default to non verbose mode
CONFIG_FILE="./bacres.conf"                                 	# wire up the expect configuration file at this location
LOG_FILE_NAME="$(date +%d%m%Y).log"                             # the name of the log file
DEBUG=0                                                         # Default mode is for non-debug

#
# The following are the Error Codes that can be raised by this script
#
SUCCESS_ERROR_CODE=0
BACKUP_LOCATION_DOES_NOT_EXIST_ERROR_CODE=1
SOURCE_LOCATION_DOES_NOT_EXIST_ERROR_CODE=2
MODE_NOT_SPECIFIED_ERROR_CODE=3
CONFIGURATION_FILE_NOT_FOUND_ERROR_CODE=4
TAR_BACKUP_ERROR_CODE=5
CONFIGURATION_FILE_NOT_SPECIFIED_ERROR_CODE=6
BACKUP_LOCATION_NOT_SPECIFIED_ERROR_CODE=7
SOURCE_LOCATION_NOT_SPECIFIED_ERROR_CODE=8
PROJECT_NAME_NOT_SPECIFIED_ERROR_CODE=9
LOG_DIRECTORY_CREATE_FAILED_ERROR_CODE=10
LOG_FILE_CREATE_FAILED_ERROR_CODE=11
RESTORE_LOCATION_NOT_SPECIFIED_ERROR_CODE=12
RESTORE_LOCATION_DOES_NOT_EXIST_ERROR_CODE=13
TAR_RESTORE_ERROR_CODE=14
NO_RESTORE_FILE_FOUND=15
TAR_RESTORE_NO_MATCHING_PATTERN_ERROR_CODE=16
 
#
# Description: 	This helper function writes to the log file and to the screen.
# Parameters: 	$1 = $LOG_FILE_NAME
#               $2 = message to write to log
#				$3 = message type (e = error,  = Information)
#  				$4 = $VERBOSE 
#
function writeToLog()
{
    #
    # Check if the log file already exists.
    # If it does not then we will create an empty log file
    #
    if [[ ! -f "$1" ]];
    then
        if ! touch "$1" > /dev/null 2>&1
        then
            echo "Error: Unable to create the log file: $1" >&2
            exit $LOG_FILE_CREATE_FAILED_ERROR_CODE
        fi
    fi

	# append line to end of file only if the directory to store the log file
	# exists otherwise just write the message to the standard output
	if [[ "$3" = "e" ]];
	then	
		#
		# Always log error messages (e)
		#
		echo "$(date +%H:%M:%S) Error: $2" 2>&1 | tee -a "$1"
	else
		#
		# Only log informational messages (i) when verbose is 1
		#
		if [[ "$4" = 1 ]];
		then
			echo "$(date +%H:%M:%S) $2" 2>&1 | tee -a "$1"
		fi
	fi

}

#
# Description:  This function displays the contents of the latest tar.gz file
#				that was created for the specified project name.
#               $1 = $PROJECT_NAME
#               $2 = $BACKUP_LOCATION
#               $3 = $FILE_FILTER
#               $4 = $LOG_FILE_NAME
#               $5 = $VERBOSE
function displayArchiveContents()
{
	#
	# Check that the backup directory was specified
	#
	if [[ -z "$2" ]];
	then 
		writeToLog "$4" "Backup directory (-b) was not specified." "e" $5
		exit $BACKUP_LOCATION_NOT_SPECIFIED_ERROR_CODE;
	fi 

    #
    # Check that the project name was specified
    #
    if [[ -z "$1" ]];
    then
        writeToLog "$4" "Project name (-p) was not specified." "e" $5
        exit $PROJECT_NAME_NOT_SPECIFIED_ERROR_CODE;
    fi
 
    # 1. Check that the backup location directory exists
    if [[ ! -d "$2" ]];
    then
        writeToLog "$4" "$2 directory does not exist." "e" $4
        exit $BACKUP_LOCATION_DOES_NOT_EXIST_ERROR_CODE;
    fi
		
	cd "$2"
    # 2. Check if there are any .tar.gz files in the backup location that start with $PROJECT_NAME
    if ls $1_*.tar.gz > /dev/null 2>&1
    then
		#
		# There are files matching project name so fetch the most recent one
		#
        ARCHIVE_TO_RESTORE=$(ls -1 "$2" | grep "$1_.*.tar.gz" | tail -1)

        if [[ -z "$ARCHIVE_TO_RESTORE" ]];
        then
            writeToLog "$4" "No file specified for restore operation" "e" $5
            exit $NO_RESTORE_FILE_FOUND
        fi

        # Display the contents of the archive
        echo "Contents of $ARCHIVE_TO_RESTORE:"

		#
		# Check to see if there are any files in the archive matching the filter. If there
		# are then go ahead and list them.
		#
        if tar -ztvf $ARCHIVE_TO_RESTORE --wildcards --no-anchored "$3" > /dev/null 2>&1
        then
            tar -ztvf $ARCHIVE_TO_RESTORE --wildcards --no-anchored "$3"
        else
            writeToLog "$4" "No files found in archive matching the pattern $3" "e" $5
        fi
    else
        writeToLog "$4" "No files found in the backup directory matching the project name '$1'." "e" $4
    fi
}

#
# Description: 	This function displays the archive files in the backup directory
#				for this project name.
#
# $1 = $PROJECT_NAME
# $2 = $BACKUP_LOCATION
# $3 = $LOG_FILE_NAME
# $4 = $VERBOSE
# $5 = $DEBUG
#
function listArchiveFiles()
{ 
	#
	# Check that the backup directory was specified
	#
	if [[ -z "$2" ]];
	then 
		writeToLog "$5" "Backup directory (-b) was not specified." "e" $4
		exit $BACKUP_LOCATION_NOT_SPECIFIED_ERROR_CODE;
	fi 

	#
	# Check that the project name was specified
	#
	if [[ -z "$1" ]];
	then 
		writeToLog "$5" "Project name (-p) was not specified." "e" $4
		exit $PROJECT_NAME_NOT_SPECIFIED_ERROR_CODE;
	fi

    # 1. Check that the backup location exists
    if [[ -d "$2" ]];
    then
		#
		# First check if the archive contains any .tar.gz files matching the project name
		#
        cd "$2"
        if ls $1_*.tar.gz > /dev/null 2>&1
        then
            #
            # use the cut command to display just the timestamp on these .tar.gz files
            #
            # 1. Calculate the position of 1st character of timestamp in filename (length of $PROJECT_NAME + 2)
            # 2. Calculate the position of the last character of timestamp in filename (start + 14). Time stamp will always be 14 length.
            #
            local start=$((${#1}+2))
            local end=$(($start+14))

            #
            # Pipe the output of ls to the cut command and display only the timestamp part of the filename
            #
            echo "The following are the timestamps of archives in "$BACKUP_LOCATION""
            ls $1_*.tar.gz | cut -c $start-$end
        else
            writeToLog "$3" "There are no archives in $BACKUP_LOCATION matching the project name $1" "e" $4
        fi
    else
        writeToLog "$3" "Backup directory $2 does not exist" "e" $4
    fi
}

#
# Description: 	This function performs the restore operation
#	Parameters: $1 = $PROJECT_NAME
#				$2 = $BACKUP_LOCATION
#				$3 = $RESTORE_LOCATION
#				$4 = $LOG_FILE_NAME
#				$5 = $VERBOSE 
#				$6 = $DEBUG
#               $7 = time stamp to restore (If blank then find the latest archive)
#               $8 = $FILE_FILTER
function restore()
{	
	writeToLog "$4" "" "i" $5
	writeToLog "$4" "*********Starting new restore job*********" "i" $5
	writeToLog "$4" "" "i" $5

    #
    # $1 = $PROJECT_NAME
    # $2 = $BACKUP_LOCATION
    # $3 = $RESTORE_LOCATION
    # $4 = $VERBOSE
    # $5 = $LOG_FILE_NAME
    #
    validateRestoreConfiguration "$1" "$2" "$3" "$5" "$4"

    ARCHIVE_TO_RESTORE="$7"

    if [[ -z $7 ]];
    then
        writeToLog "$4" "No restore file specified. Searching for most recent backup file" "i"

        #
        # If no archive name is specified then search for the most recent tar.gz file in the backup folder
        # ls will list the files in order of their name. We can pipe the result to grep to show files that
        # match the regular expression "$1*.tar.gz. We are only interested in the last result so we can
        # use tail to get this and exclude all other matching results
        #
        ARCHIVE_TO_RESTORE=$(ls -1 "$2" | grep "$1.*.tar.gz" | tail -1)

        if [[ -z "$ARCHIVE_TO_RESTORE" ]];
        then
            writeToLog "$4" "No file specified for restore operation" "e" $5
            exit $NO_RESTORE_FILE_FOUND
        fi
    else
        # a timestamp was specified so restore the file with that timestamp
        ARCHIVE_TO_RESTORE="$1_$7.tar.gz"
    fi

    writeToLog "$4" "Restoring the file $2/$ARCHIVE_TO_RESTORE to $3" "i" $5

    # verify that the file exists in the backup directory
    if [[ -f "$2/$ARCHIVE_TO_RESTORE" ]];
    then  
        # x         option stands for extract.
        # p         option preserve file permissions
        # f         option states that the very next argument will be the name of the archive file
        # --wildcard option filters the restore operation to only restore specific files matching the pattern
        # --no-anchored instructs patterns to match only after a '/' delimiter
        #
        # Before performing the restore test that there are files in the archive matching the pattern specified
        # This will return 0/true if successful and will swallow any error message that would get printed to screen
        #
        if tar -ztvf "$2/$ARCHIVE_TO_RESTORE" --wildcards --no-anchored "$8" > /dev/null 2>&1
        then

            # Perform the restore operation
            # Restore to default location if no restore location specified
            #
            if [[ -z "$3" ]];
            then
                echo "The archive $ARCHIVE_TO_RESTORE will now be restored to it's original location."

                # Restore the files to the original file location
                if tar -xvf "$2/$ARCHIVE_TO_RESTORE" -C / --wildcards --no-anchored "$8" > /dev/null 2>&1
                then
                    writeToLog "$4" "Restore to original location completed successfully." "i" "1"
                else
                    writeToLog "$4" "An error was encountered while attempting the restore operation. Error code=$?." "e" $5
                    exit $TAR_RESTORE_ERROR_CODE
                fi
            else
                if [[ -d "$3" ]];
                then
                    echo "The archive $ARCHIVE_TO_RESTORE, will now be restored to: $3"

                    # Restore the files to an alternate location
                    if tar -xzpf "$2/$ARCHIVE_TO_RESTORE" -C "$3" --wildcards --no-anchored "$8"  > /dev/null 2>&1
                    then
                        writeToLog "$4" "Restore to alternative location completed successfully." "i" "1"
                    else
                        writeToLog "$4" "An error was encountered while attempting the restore operation. Error code=$?." "e" $5
                        exit $TAR_RESTORE_ERROR_CODE
                    fi
                else
                    writeToLog "$4" "Invalid restore location specified: $3" "e" $5
                fi
            fi
        else
            writeToLog "$4" "Restoring the file $2/$ARCHIVE_TO_RESTORE. No files in archive matching the pattern $8." "e" $5
            exit $TAR_RESTORE_NO_MATCHING_PATTERN_ERROR_CODE
        fi
    else
        echo "Error: the file $2/$ARCHIVE_TO_RESTORE does not exist. Restore cannot be completed."
        exit $NO_RESTORE_FILE_FOUND
    fi
}

#
# Description: 	This function performs the backup operation
# Parameters:		$1 = $SOURCE_LOCATION
# 					$2 = $BACKUP_LOCATION
# 					$3 = $PROJECT_NAME
#					$4 = $VERBOSE			
#					$5 = $LOG_FILE_NAME
#					$6 = $DEBUG
#                   $7 = $BACKUP_FILENAME
#
function backup()
{
	writeToLog "$5" "" "i" $4
	writeToLog "$5" "*********Starting new backup job*********" "i" $4
	writeToLog "$5" "" "i" $4

    # Parameters: 	$1 = $PROJECT_NAME
    #				$2 = $BACKUP_LOCATION
    #				$3 = $SOURCE_LOCATION
    #				$4 = $VERBOSE
    #               $5 = $LOG_FILE_NAME
    validateBackupConfiguration "$3" "$2" "$1" "$4" "$5"

    writeToLog "$5" "Starting backup of $1 to $2" "i" $4

	#
	# When verbose mode enabled write the list of files being backed up to standard output
	#
	if [[ $4 = 1 ]];
	then
		tar -cvzPf "$2"/"$7" "$1" 	# use the tar command to do the backup
	else
		tar -czPf "$2"/"$7" "$1" 		# use the tar command to do the backup
	fi
	
    # check the exit code from tar command for success or failure
	if [ $? != 0 ]; then
		writeToLog "$5" "An error was encountered while attempting backup operation. Error code=$?." "e" $4
		exit $TAR_BACKUP_ERROR_CODE
	else 
		writeToLog "$5" "Backup completed successfully." "i" $4
        writeToLog "$5" "*********End of backup job*********" "i" $4
	fi
} 

#
# Description:	Prints out the value of each variable used in the script.
#				Indicates if the configuration setting is from the configuration file
#				or from a parameter supplied by the user from the command line.
# Parameters: 	$1 =  $SOURCE_LOCATION
#				$2 =  $SOURCE_LOCATION_FROM_CONFIG_FILE
#				$3 =  $BACKUP_LOCATION
#               $4 =  $BACKUP_LOCATION_FROM_CONFIG_FILE
#				$5 =  $BACKUP_FILENAME
#				$6 =  $LOG_FILE_NAME 
#				$7 =  $LOG_FILE_LOCATION_FROM_CONFIG_FILE
#               $8 =  $VERBOSE
#               $9 =  $VERBOSE_FROM_CONFIG_FILE
#               $10 = $USER_ACTION_REQUEST
#               $11 = $USER_ACTION_REQUEST_FROM_CONFIG_FILE
#               $12 = $PROJECT_NAME
#               $13 = $PROJECT_NAME_FROM_CONFIG_FILE
#               $14 = $CONFIG_FILE
#               $15 = $RESTORE_LOCATION
#               $16 = $RESTORE_LOCATION_FROM_CONFIG_FILE
function printConfiguration()
{
    writeToLog "$6" "Parameter Configuration [(C)=From Config File,(U)=User specified]"   "i" "$8"
    writeToLog "$6" "******************************************************************" "i" $8
    writeToLog "$6" "Script Action(${11})     = ${10}" "i" $8
	writeToLog "$6" "Source location(${2})   = $1" "i" $8
    writeToLog "$6" "Backup location(${4})   = $3" "i" $8
    writeToLog "$6" "Project name(${13})      = ${12}" "i" $8
	writeToLog "$6" "Log file name(${7})     = $6" "i" $8
	writeToLog "$6" "Verbose(${9})           = $8" "i" $8
    writeToLog "$6" "Backup file name     = $5" "i" $8
    writeToLog "$6" "Config File          = ${14}" "i" $8
    writeToLog "$6" "******************************************************************" "i" ${8}
}

#
# Description:	This validates that all settings are correct before proceeding for the backup job.
#				If requires settings are missing then the function will display a message and exit the
#				script.
# Parameters: 	$1 = $PROJECT_NAME
#				$2 = $BACKUP_LOCATION
#				$3 = $SOURCE_LOCATION 
#				$4 = $VERBOSE	
#               $5 = $LOG_FILE_NAME
function validateBackupConfiguration()
{	  
	#
	# Check that the project name was specified
	#
	if [[ -z "$1" ]];
	then
		writeToLog "$5" "Project name (-p) was not specified." "e" $4
		exit $PROJECT_NAME_NOT_SPECIFIED_ERROR_CODE;
	fi
		 
	#
	# Check that the backup directory was specified
	#
	if [[ -z "$2" ]];
	then 
		writeToLog "$5" "Backup directory (-b) was not specified." "e" $4
		exit $BACKUP_LOCATION_NOT_SPECIFIED_ERROR_CODE;
	fi
	
	#
	# Check that the backup directory exists
	#
	if [[ ! -d "$2" ]]; 
	then
		writeToLog "$5" "$2 directory does not exist." "e" $4
		exit $BACKUP_LOCATION_DOES_NOT_EXIST_ERROR_CODE;
	fi

	#
	# Check that the source directory was specified
	#
	if [[ -z "$3" ]];
	then
		writeToLog "$5" "Source directory (-s) was not specified." "e" $4
		exit $SOURCE_LOCATION_NOT_SPECIFIED_ERROR_CODE;
	fi
	
	#
	# If no source file OR directory specified for backup then display error and exit
	#
	if [[ (! -d "$3") && (! -f "$3") ]]; 
	then
        writeToLog "$5" "Source file/directory not found: $3" "e" $4
		exit $SOURCE_LOCATION_DOES_NOT_EXIST_ERROR_CODE; 	
	fi		
}

#
# Description:	This validates that all settings are correct before proceeding for the restore
#				If requires settings are missing then the function will display a message and exit the
#				script.
# Parameters: 	$1 = $PROJECT_NAME
#				$2 = $BACKUP_LOCATION
#				$3 = $RESTORE_LOCATION 
#				$4 = $VERBOSE	
#               $5 = $LOG_FILE_NAME
function validateRestoreConfiguration()
{	  
	#
	# Check that the project name was specified
	#
	if [[ -z "$1" ]];
	then
		writeToLog "$5" "Project name (-p) was not specified." "e" $4
		exit $PROJECT_NAME_NOT_SPECIFIED_ERROR_CODE;
	fi
		 
	#
	# Check that the backup directory was specified
	#
	if [[ -z "$2" ]];
	then 
		writeToLog "$5" "Backup directory (-b) was not specified." "e" $4
		exit $BACKUP_LOCATION_NOT_SPECIFIED_ERROR_CODE;
	fi 

	#
	# Check that the backup directory exists
	#
	if [[ ! -d "$2" ]]; 
	then
		writeToLog "$5" "$2 backup directory does not exist." "e" $4
		exit $BACKUP_LOCATION_DOES_NOT_EXIST_ERROR_CODE;
	fi

	#
	# If not restore location is not a directory then display error and exit
	#
	if [[ (-n "$3") && (! -d "$3") ]];
	then
        writeToLog "$5" "Restore location not found: $3" "e" $4
		exit $RESTORE_LOCATION_DOES_NOT_EXIST_ERROR_CODE; 	
	fi		
}

#
# Description:	This function displays usage details / help for this script.
#
function usage()
{
cat <<EOF
NAME
	bacres.sh -- backup and restore files and directories
	
SYNOPSIS
	bacres.sh [-C] [options]
	
DESCRIPTION
	bacres.sh backs up and restores files and folders. By default it will use a configuration file to determine
	what files are to be backed up or restored. The default configuration file is bacres.conf and
    the script expects to find this file in the same directory as the script. To use an alternative
    configuration file it is necessary to use the -C parameter option. This must be the first paramter
    supplied to the script.

    -C FILE,
    optional argument that can be used to specify a custom configuration file. This must be the specified as the
    first parameter when using a custom configuration file.

Command line options:
    
    -B,
        indicates that the script should perform a backup job.
    -R,
        indicates that the script should perform a restore job.
    -D,
        indicates that the script should displays the contents of the latest .tar.gz file for the specific project.
    -h,
        display usage options for this script.
    -l DIRECTORY,
        used to override the default directory that will store the log file.
    -L,
        indicates that the script should list all .tar.gz files for a specific project in the directory
        that stores the backup files.
    -p,
        used to specify the project name. This is prefixed to the .tar.gz file created by the backup job.
    -b DIRECTORY,
        This the directory where the backup files are stored.
    -r DIRECTORY,
        used in conjunction with -R. This overrides the directory that files will be restored to.
    -s DIRECTORY|FILE,
        this is the file/directory that is to be backed up.
    -t TIMESTAMP,
        the timestamp of the file to restore.
    -V,
        verbose logging, This option enables detailed/verbose logging. Verbose logging is disabled by default.
    -w,
        used in conjunction with -R. This enables a file filter to be applied to restores and listings.

EOF
}

########################### Main ##############################
BACKUP_LOCATION_FROM_CONFIG_FILE="C"
RESTORE_LOCATION_FROM_CONFIG_FILE="C"
PROJECT_NAME_FROM_CONFIG_FILE="C"
SOURCE_LOCATION_FROM_CONFIG_FILE="C"
VERBOSE_FROM_CONFIG_FILE="C"
USER_ACTION_REQUEST_FROM_CONFIG_FILE="C"
LOG_FILE_LOCATION_FROM_CONFIG_FILE="C"
USER_ACTION_REQUEST="BACKUP"
FILE_FILTER="*.*"
USE_CONFIG_FILE="N"

if [[ ($1 = "-h" || $1 = "--help") ]];
then
    usage
    exit
fi

#
# If no command line arguments specified then try to use config file
#
if [[ $# = 0 ]];
then
	# set flag indicating script will need to load a config file
	USE_CONFIG_FILE="Y"		
fi

#
# Check the first parameter to see if the configuration file
# was specified as this parameter must be processed first
#
if [[ $1 = "-C" ]];
then
	USE_CONFIG_FILE="Y"		# set flag indicating script will need to load a config file
    shift
    if [[ -n "$1" ]];
    then
        CONFIG_FILE="$1"
        shift
    else
        echo "Error: Configuration file not specified for parameter -C." >&2
        exit $CONFIGURATION_FILE_NOT_SPECIFIED_ERROR_CODE
    fi
fi 

#
# If USE_CONFIG_FILE is Y at this stage then we need to import the config file settings
#
if [[ $USE_CONFIG_FILE = "Y" ]];
then 
	#
	# Before importing the configuration file check that files exists on the file system	
	#
	if [[ ! -f "$CONFIG_FILE" ]];
	then
	    echo "Error: The configuration file: $CONFIG_FILE was not found" >&2		# write message to the standard error 	(logging not configured yet)
	    exit $CONFIGURATION_FILE_NOT_FOUND_ERROR_CODE
	else
		#
		# Import all settings from the configuration file
		# 
		source "$CONFIG_FILE"
	fi
fi

#
# Check if any input parameters were specified
#
if [[ $# > 0 ]];
then  
    #
    # Read any arguments that were specified on the command line
	#
    while getopts "b:BC:Dhl:Lp:w:vr:Rs:t:V" OPTION
	do 
		case $OPTION in
            B)
                USER_ACTION_REQUEST="BACKUP"
                USER_ACTION_REQUEST_FROM_CONFIG_FILE="U"
                ;;
			b)
                # Read the name of the directory where the backup file will be stored.
                #
				BACKUP_LOCATION="$OPTARG"
                BACKUP_LOCATION_FROM_CONFIG_FILE="U"
				;;
            D)
                #
                # Display the contents of a backup file
                #
                USER_ACTION_REQUEST="DISPLAY"
                USER_ACTION_REQUEST_FROM_CONFIG_FILE="U"
                ;;
            l)
                LOG_FILE_LOCATION="$OPTARG"
                LOG_FILE_LOCATION_FROM_CONFIG_FILE="U"
                ;;
            L)
                #
                # List all timestamps in an archive
                #
                USER_ACTION_REQUEST="LIST"
                USER_ACTION_REQUEST_FROM_CONFIG_FILE="U"
                ;;
                p)
                # Read the option for project name. This will be prefixed
                # to the backup file name
                #
				PROJECT_NAME="$OPTARG"
                PROJECT_NAME_FROM_CONFIG_FILE="U"                 
                ;;
            R)
                USER_ACTION_REQUEST="RESTORE"
                USER_ACTION_REQUEST_FROM_CONFIG_FILE="U"
                ;;
            r)
                #
                # Read the name of the directory where files should be stored.
                #
                RESTORE_LOCATION="$OPTARG"
                RESTORE_LOCATION_FROM_CONFIG_FILE="U"
                ;;
            s)
                # Read the name of the file or directory that is to be backed up.
                #
                SOURCE_LOCATION="$OPTARG"
                SOURCE_LOCATION_FROM_CONFIG_FILE="U"
				;;
			t)
                # Specify a timestamp to restore
                #
                USER_ACTION_REQUEST="RESTORE"
                TIME_STAMP="$OPTARG"
                ;;
            V)
                #
                # Enable verbose logging mode
                #
                VERBOSE="1"
                VERBOSE_FROM_CONFIG_FILE="U"
                ;;
            w)
                # wilcard filter that ensures only specific files are restored by the tar command
                # e.g. *.txt will only restore files ending in .txt
                FILE_FILTER="$OPTARG"
                ;;
           *)
                usage
                exit
            ;;
        esac
    done
fi

#
# Setup the name of the log file
# 
if [[ -n $LOG_FILE_LOCATION ]];
then
    LOG_FILE_NAME="$LOG_FILE_LOCATION"/"$LOG_FILE_NAME"
fi

#
# Determine the name of the backup file
#
DATE_PART=$(date +%Y%m%d)           # format: YYYYMMDD
HOUR_PART=$(date +%H%M%S)           # format: HHMMSS
BACKUP_FILENAME="${PROJECT_NAME}_${DATE_PART}_${HOUR_PART}.tar.gz"

#
# Print out the value of configuration parameters used by the script
#
# Parameters: 	$1 =  $SOURCE_LOCATION
#				$2 =  $SOURCE_LOCATION_FROM_CONFIG_FILE
#				$3 =  $BACKUP_LOCATION
#               $4 =  $BACKUP_LOCATION_FROM_CONFIG_FILE
#				$5 =  $BACKUP_FILENAME
#				$6 =  $LOG_FILE_NAME"
#				$7 =  $LOG_FILE_LOCATION_FROM_CONFIG_FILE
#               $8 =  $VERBOSE
#               $9 =  $VERBOSE_FROM_CONFIG_FILE
#               $10 = $USER_ACTION_REQUEST
#               $11 = $USER_ACTION_REQUEST_FROM_CONFIG_FILE
#               $12 = $PROJECT_NAME
#               $13 = $PROJECT_NAME_FROM_CONFIG_FILE
#               $14 = $CONFIG_FILE
#               $15 = $RESTORE_LOCATION 
#               $16 = $RESTORE_LOCATION_FROM_CONFIG_FILE
printConfiguration "$SOURCE_LOCATION" $SOURCE_LOCATION_FROM_CONFIG_FILE "$BACKUP_LOCATION" $BACKUP_LOCATION_FROM_CONFIG_FILE "$BACKUP_FILENAME" "$LOG_FILE_NAME" $LOG_FILE_LOCATION_FROM_CONFIG_FILE $VERBOSE $VERBOSE_FROM_CONFIG_FILE "$USER_ACTION_REQUEST" $USER_ACTION_REQUEST_FROM_CONFIG_FILE "$PROJECT_NAME" $PROJECT_NAME_FROM_CONFIG_FILE "$CONFIG_FILE" "$RESTORE_LOCATION" $RESTORE_LOCATION_FROM_CONFIG_FILE
  
#
# Perform the required backup or restore task
#
if [[ $USER_ACTION_REQUEST = "BACKUP" ]];
then
    #
    # Call backup function to perform the backup
    #
    backup "$SOURCE_LOCATION" "${BACKUP_LOCATION}" "${PROJECT_NAME}" $VERBOSE "${LOG_FILE_NAME}" $DEBUG "$BACKUP_FILENAME"

elif [[ $USER_ACTION_REQUEST = "LIST" ]];
then
    #
    # Call function to list all .tar.gz files in the backup directory for the project specified
    #
    listArchiveFiles "$PROJECT_NAME" "$BACKUP_LOCATION" "$LOG_FILE_NAME" $VERBOSE $DEBUG

elif [[ $USER_ACTION_REQUEST = "DISPLAY" ]];
then
    #
    # Call function to display the contents of most latest .tar.gz file for the project specified
    #
    displayArchiveContents "$PROJECT_NAME" "$BACKUP_LOCATION" "$FILE_FILTER" "$LOG_FILE_NAME" $VERBOSE
elif [[ $USER_ACTION_REQUEST = "RESTORE" ]];
then
    #
    # Call restore function to perform the restore
    #
    restore "$PROJECT_NAME" "$BACKUP_LOCATION" "$RESTORE_LOCATION" "$LOG_FILE_NAME" $VERBOSE $DEBUG "$TIME_STAMP" "$FILE_FILTER"
else
    echo "Error: unknown request ($USER_ACTION_REQUEST) specified." >&2
fi

# If code reaches here then return success status code
exit $SUCCESS_ERROR_CODE