Author: John Brennan (R00104987)

DESIGN DOCUMENT
===============

Resources
--------
design.txt  - design document for this assignment
bacres.sh   - bash script file that performs backup and restore operations
bacres.conf - configuration file that is used by the bash script bacres.sh.

Design Assumptions
-----
1. If no input parameters are specified then the configuration file settings will always be used. The script will raise an error and exit if it cannot find the configuration file. 
2. The default mode of the bacres.sh script is to perform a backup job. The mode can be changed using any of the following parameters -B,-R,-L,-D.
3. The default configuration file is bacres.conf and it resides in the same directory as the script file bacres.sh.
4. Timestamps used on backup files are in the format YYYYMMDD_HHMMSS, e.g. 20130315_101530.tar.gz
5. If an option is specified on the command line (with the exception of -C) then the script will expect all required inputs from the command line options. An error will be displayed if a required option is missing. 
6. Verbose logging is disabled by default. Only errors will be logged to the log file when verbose logging is disabled.
7. The script can backup a directory or an individual file.
8. The script supports directory names that contain a space.
9. When using a custom configuration file it is necessary to supply the -C option along with the name of the configuration file. This -C option must be the first option in the command line arguments in this scenario.
10. This script is designed to run on Ubuntu 12.10.
11. This script requires the default configuration file bacres.conf to exist. It is not necessary for this fie to contain any data. 
12. It is possible to specify a custom configuration file. It is possible to override specific settings in the configuration file with command line arguments (i.e. mix command line and config file settings).

Program Flow
--------

The user input can be specified via the command line or from a configuration file. By default, the script will use the settings in the configuration file. The configuration file is called bacres.conf and it is assumed that this file exists in the same directory as the script bacres.sh. 

The script performs the following high level actions:

1. It determines if it should use the default configuration file bacres.conf or if the user has instead specified a custom configuration file using the -C parameter option. 
2. Next the configuration file settings are imported. This seeds all configuration parameters with the default value as provided in the configuration file.
3. Next, user specified settings are read from the command line using getopts. The user specified settings override the setting in the configuration file. Whenever an option is specified via the command line a variable is set to indicate that this option is user specific (U) and overrides the setting in the configuration file ©. The parameters -B, -R, -L and -D are used to drive the action that will be performed by the script. By default the script assumes that the default action is -B, i.e. BACKUP job.
4. Next a call is made to the function printConfiguration(). This prints out all of the application settings to the screen. Any values that are from the configuration file are printed with (C) and any values that are specified by the user from the command line are denoted with (U).
5. There are 4 possible tasks that can be carried out by the script. These tasks are as follows: 
	BACKUP - specify the -B option to perform a backup job.
	RESTORE - specify the -R option to perform a restore job.
	LIST 	- specify the -L option to list the timestamps for a specific project.
	DISPLAY	- specify the -D option to display the contents of the most recent archive.
Now a decision is made about whether we need to perform a Restore task or a Backup task.
6. For backup task it is straightforward, there is only 1 possible option, i.e. to backup the files. The backup function is invoked for this and it is implemented using a call to the tar command.
7. The backup function performs validation of the parameters passed to it through a call to the function "validateBackupConfiguration" which checks that all of the input parameters are correct before allowing the backup job to proceed. The validation function performs the following checks:
    a. Check that the project name that is prefixed to the backup file name was specified.
    b. Check that the directory that will store the backup was specified.
    c. Check that the directory that will store the backup exists.
    d. Check that the source/target directory/file that is to be backed up was specified.
    e. Check that the source/target directory/file that is to be backed up exists.
8. The restore function performs validation of the parameters passed to it through a call to the function "validateRestoreConfiguration" which checks that all of the input parameters are correct before allowing the restore job to proceed. The validation function performs the following checks:
    a. Check that the project name that is prefixed to the backup file name was specified.
    b. Check that the directory that stores the backup was specified.
    c. Check that the directory that store the backup file exists.
    d. Check that the directory to restore the backup to was specified.
    e. Check that the directory to restore the backup to exists.

Config File Settings
-----

The following settings need to be configured via the configuration (bacres.conf) file:

SOURCE_LOCATION		- The directory or file that will be backed up.
BACKUP_LOCATION		- The directory that will store the backup file.
LOG_FILE_LOCATION   	- The directory where log files will be created.
PROJECT_NAME		- This is the name that will be prefixed to the tar file created for the backup
USER_ACTION_REQUEST   	- This is the default action/mode that the script will perform. This can have one of the following values "BACKUP","RESTORE","LIST" or "DISPLAY".
DEBUG               	- Used for developer debugging purposes. When set to 1 the detailed debug information is written to the standard output instead of the log file.
VERBOSE             	- Enables or disables verbose logging mode. Verbose logging is disabled by default.

The following parameters will be available for the script resbac.sh:
-C FILE,
	optional argument that can be used to specify a custom configuration file.
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
        indicates that the script should list all .tar.gz files for a specific project in the directory that stores the backup files.
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
        used to filter file listing for restores and archive content listings.

 
Backup Sample Usage Commands
----------------------------

1. Command Line Options:

Scenario: Back up the directory "/home/jbrennan/Documents" to the directory "/home/jbrennan/backups". The backup file will be prefixed with project name "test" and verbose logging is enabled.

./bacres.sh -B -p "test" -b "/home/jbrennan/backups" -s "/home/jbrennan/Documents" -V

Output of this command to standard output:

07:47:31 Parameter Configuration [(C)=From Config File,(U)=User specified]
07:47:31 ******************************************************************
07:47:31 Script Action(U)     = BACKUP
07:47:31 Source location(U)   = /home/jbrennan/Documents
07:47:31 Backup location(U)   = /home/jbrennan/backups
07:47:31 Project name(U)      = test
07:47:31 Log file name(C)     = 28032013.log
07:47:31 Verbose(U)           = 1
07:47:31 Backup file name     = test_20130328_074731.tar.gz
07:47:31 Config File          = ./bacres.conf
07:47:31 ******************************************************************
07:47:31 
07:47:31 *********Starting new backup job*********
07:47:31 Starting backup of /home/jbrennan/Documents to /home/jbrennan/backups 
a /home/jbrennan/Documents
a /home/jbrennan/Documents/2685112806_00d0903802_o.jpg
a /home/jbrennan/Documents/6056346087_d721b009a8_o.jpg
07:47:31 Backup completed successfully.

2. Config file options (no interaction)
 
The script can be run without any command line parameters:

./bacres.sh

N.B. It is possible to specify an alternate location for the configuration file which will force the script to use a custom different configuration file:

./bacres.sh -C "/home/jbrennan/myconfig.conf"

Restore Sample Usage
-------------------

Command Line Options:

1. List the archive files for the current project "test":

./bacres.sh -L -b "/home/jbrennan/backups" -p "test"

This will list all timestamps in the backup directory that match the current "test" project.
  
2. List the contents of the most recent archive:

./bacres.sh -D -b "/home/jbrennan/backups/" -p "test"

3. List the contents of the most recent archive that match *.sh file pattern

./bacres.sh -D -b "/home/jbrennan/backups/" -p "test" -w "*.sh"
  
4. Restore the latest archive matching the project name "test"

./bacres.sh -R -p "test" -b "/home/jbrennan/backups"

5. Restore just files matching .pdf in the latest archive:

./bacres.sh -R -p "test" -b "/home/jbrennan/backups" -w "*.pdf"

6. Restore a specific timestamp to its original location:

./bacres.sh -R -p "test" -t 20130328_075405 -b "/home/jbrennan/backups/"

7. Restore a specific timestamp to alternative location:

./bacres.sh -R -t 20130328_070642 -r "/home/jbrennan/restores/" -p "test" -b "/home/jbrennan/backups"

8. Restore just files matching *.jpg in timestamp:

./bacres.sh -R -t 20130328_070642 -p "test" -b "/home/jbrennan/backups" -w "*.jpg"

BACKUP
-----

The backup function will take care of invoking the tar command to perform the backup. It will check the return
code from the tar job to ensure that no errors occurred. The status code will be checked after calling tar to ensure it returned 0 (for success).

RESTORE
-------

The restore function will take care of invoking the tar command to perform the restore. It will check the return
code from the tar job to ensure that no errors occurred. The status code will be checked after calling tar to ensure it returned 0 (for success).

LOGGING
-------

A helper function writeToLog() was created so that logging of errors and informational messages could be made more straightforward. When verbose mode is enabled (-V) all output is logged to the log file (standard output and standard error). When verbose mode is not enabled then only standard error is sent to the log file and to the screen. The following article was used to output both standard error and standard output to the log file and the screen at the same time. http://www.skorks.com/2009/09/using-bash-to-output-to-screen-and-file-at-the-same-time/. 

RETURN CODES
-------

The script return 0 if it completes without error. Otherwise the following error codes may be returned if an error condition is encountered:

  BACKUP_LOCATION_DOES_NOT_EXIST_ERROR_CODE	=1
  SOURCE_LOCATION_DOES_NOT_EXIST_ERROR_CODE	=2
  MODE_NOT_SPECIFIED_ERROR_CODE			=3
  CONFIGURATION_FILE_NOT_FOUND_ERROR_CODE	=4
  TAR_BACKUP_ERROR_CODE				=5
  CONFIGURATION_FILE_NOT_SPECIFIED_ERROR_CODE	=6
  BACKUP_LOCATION_NOT_SPECIFIED_ERROR_CODE	=7
  SOURCE_LOCATION_NOT_SPECIFIED_ERROR_CODE	=8
  PROJECT_NAME_NOT_SPECIFIED_ERROR_CODE		=9
  LOG_DIRECTORY_CREATE_FAILED_ERROR_CODE	=10
  LOG_FILE_CREATE_FAILED_ERROR_CODE		=11
  RESTORE_LOCATION_NOT_SPECIFIED_ERROR_CODE	=12
  RESTORE_LOCATION_DOES_NOT_EXIST_ERROR_CODE	=13
  TAR_RESTORE_ERROR_CODE			=14
  NO_RESTORE_FILE_SPECIFIED			=15
  TAR_RESTORE_NO_MATCHING_PATTERN_ERROR_CODE	=16
