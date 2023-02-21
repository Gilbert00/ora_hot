Program Appointment:
Hot copying of Oracle databases by NetBackup.

Description:
The ora_hot.sh program is called in an Oracle-type backup policy at backup system NetBackup.

Parameter file:
File name - ora_bk_params.txt.
1st line - file version, first symbol in line is # !
line i - the line contains 10 fields:
	field 1 - Base Name
	field 2 - Base SID
	field 3 - streams count for backup base files
	field 4 - streams count for backup archlogs
	field 5 - a 2-letter string indicates which node the data is copied from (symbols P or S):
		the 1st character indicates where the database files are copied from
		the 2d character indicates where the archlogs are copied from
		P - backup do from primary
		S - backup do from standby
	field 6 - 3 digits binary flag:
		flag 0: =1 - backup is in test mode VALIDATE
			=0 - backup is in real mode
		flag 1: =1 - archlogs after backup from the node are removed from it
			=0 - archlogs after backup from the node aren't removed from it 
		flag 2: =1 - archlogs are removed from other node
			=0 - archlogs aren't removed from other node
	fields 7-9 - the fields are reserved for future use
	field 10 - base ORACLE_HOME
The last line describes the RMAN repository:
	field 1 - TNSname RMAN repository; if it has the value none, then the RMAN repository is not used.
	field 7 - RMAN repository login password (login - rman) 

Integration with NetBackup:
The program receives the following parameters from NetBackup via system environment:
NB_ORA_SERV
NB_ORA_CLIENT
NB_ORA_POLICY
NB_ORA_PC_SCHED
NB_ORA_FULL
NB_ORA_INCR
NB_ORA_CINC  

The program works with one policy.
Starting Schedulers must have the suffix
_AL and type Full Backup to launch archlogs
_full and type Full Backup to launch base full backup
_diff and type DiffIncr Backup to launch base differencial backup

First part of Scheduler name - base name
Examples:
RRKRMA_AL
RRKRMA_full
RRKRMA_diff

Schedulers running backup are of the type Application Backup and their names
for base files - ShortClientName 
for archlogs - ShortClientName_AL
ShortClientName - in lowercase !
Examples:
rrkrma-or5001lv	
rrkrma-or5001lv_AL
 
 

 	 

