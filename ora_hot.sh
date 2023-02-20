#!/bin/bash
#
# v 1.3.2
#
# Usage: ora_hot #<DBTARGET> <SCRIPT_DIR>
#
# TO-DO: check for another backup before start
#
cPrimaryDB="PRIMARY"
cPhStandbyDB="PHYSICAL STANDBY"
cLgStandbyDB="LOGICAL STANDBY"
readonly cPrimaryDB cPhStandbyDB cLgStandbyDB
cRolePrimary=0
cRoleStandby=1
cRoleError=9
readonly cRolePrimary cRoleStandby cRoleError
cCallTypeDB=full
cCallTypeDBfull=full
cCallTypeDBdiff=diff
cCallTypeAL=arch
readonly cCallTypeDB cCallTypeDBfull cCallTypeDBdiff cCallTypeAL

#----------------- Get params
VALID=
#VALID=VALIDATE

DIR=$(dirname $0)
TST_LOG=${DIR}/tst.log
date >> $TST_LOG
echo "NB_ORA_SERV:$NB_ORA_SERV" >> $TST_LOG
echo "NB_ORA_CLIENT:$NB_ORA_CLIENT" >> $TST_LOG
echo "NB_ORA_POLICY:$NB_ORA_POLICY" >> $TST_LOG
#echo "NB_ORA_SCHED:$NB_ORA_SCHED" >> $TST_LOG
echo "NB_ORA_PC_SCHED:$NB_ORA_PC_SCHED" >> $TST_LOG

if [[ -z $NB_ORA_PC_SCHED ]]; then  
  echo "Scheduler name is empty !"  >> $TST_LOG
  exit 1
fi

DBTARGET=$(echo $NB_ORA_PC_SCHED | awk -F_ '{print $1}')
echo "DBTARGET:$DBTARGET" >> $TST_LOG

SchedOut=""
if [[ $NB_ORA_PC_SCHED =~ _AL ]]; then
# Condition can be changed to =~ _AL
   echo "BK type: AL"  >> $TST_LOG
  SCRT_TYPE=$cCallTypeAL
	SchedOut="_AL"
elif [[ $NB_ORA_PC_SCHED =~ diff ]]; then
	echo "BK type: diff"  >> $TST_LOG
  SCRT_TYPE=$cCallTypeDBdiff
#	SchedOut="_diff"
elif [[ $NB_ORA_PC_SCHED =~ full ]]; then
	echo "BK type: full"  >> $TST_LOG
  SCRT_TYPE=$cCallTypeDBfull
#	SchedOut="_full"
else
# Can be changed!
  echo "BK type: not AL"  >> $TST_LOG
  SCRT_TYPE=$cCallTypeDB
#	SchedOut=""
fi

#echo "DIR:$DIR" >> $TST_LOG
echo "SCRT_TYPE:${SCRT_TYPE}" >> $TST_LOG

PSWD_FILE="$DIR/ora_bk_params.txt"
#export PSWD_FILE
echo "PSWD_FILE:${PSWD_FILE}" >> $TST_LOG

if [[ ! -f ${PSWD_FILE} ]]; then
  echo "Params file ${PSWD_FILE} doesn't exists !" >> $TST_LOG
  exit 1
fi  

#DBTARGET=$1
#DIR=$2
#SCRT_TYPE=$3

#RMAN_LOG_FILE="/tmp/rman_${DBTARGET}_${SCRT_TYPE}.log"
RMAN_LOG_FILE="/tmp/rman_${DBTARGET}_${SCRT_TYPE}_$(date +%Y%m%d_%H%M).log"
echo "RMAN_LOG_FILE:$RMAN_LOG_FILE" >> $TST_LOG

echo >> $RMAN_LOG_FILE
chmod 666 $RMAN_LOG_FILE

CLIENT_SHORT=`hostname`
CLIENT_SHORT=$(echo ${CLIENT_SHORT} | awk -F. '{print $1}')
#SCRIPT_NAME="${CLIENT_SHORT}_ora_${SCRT_TYPE}.sh"
SCRIPT_NAME=$(basename $0)
#CLIENT="${CLIENT_SHORT}.datacenter.cnt"
CLIENT_SHORT_UP=`echo "${CLIENT_SHORT}" | tr "[a-z]" "[A-Z]"`
#echo "CLIENT_SHORT_UP:$CLIENT_SHORT_UP" >> $RMAN_LOG_FILE

function check_SchedOut() {
# $SchedOut $RMAN_LOG_FILE
  local Sched=$1
	local Log=$2

	local RCbpbackup=$(/usr/openv/netbackup/bin/bpbackup -w -t 0 -p ${NB_ORA_POLICY} -s $Sched /home/bkp/test 2>&1 | awk '{print $3}')

  if [[ "$RCbpbackup" == "237:" ]]; then
	  echo "Schedule $RCbpbackup does not exist in the active policy ${NB_ORA_POLICY} !" >> $Log
		exit 237
	elif [[ "$RCbpbackup" == "230:" ]]; then
	  echo "The specified policy ${NB_ORA_POLICY} does not exist !" >> $Log
		exit 230	
	else
	  return
	fi
}

function get_nb_version() {
	echo $(cat /usr/openv/netbackup/bin/version | awk '{print $NF}')
}

function is_big_nb_version() {
	local Version=$(get_nb_version)
	if [[ $Version > "8.9.9.9" ]]; then
		echo 0
	else
		echo 1
	fi
}

SchedOut="${CLIENT_SHORT}$SchedOut"
[[ $(is_big_nb_version) == 0 ]] && check_SchedOut $SchedOut $RMAN_LOG_FILE

echo Script $SCRIPT_NAME >> $RMAN_LOG_FILE
echo ==== started on `date` ==== >> $RMAN_LOG_FILE
echo >> $RMAN_LOG_FILE

echo "DBTARGET:$DBTARGET" >> $RMAN_LOG_FILE 
#echo "DIR:$DIR" >> $RMAN_LOG_FILE

DB_HOME=`grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $10}'`
echo "DB_HOME:${DB_HOME}" >> $RMAN_LOG_FILE

ORACLE_SID=`grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $2}'`
NStrmBase=$(grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $3}')
NStrmALog=$(grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $4}')
BkServers=$(grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $5}')
Flags=$(grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $6}')
PSWD_TARGET=`grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $7}'`
ORACLE_HOME=`grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $10}'`
#DIR_ARCH=`grep -h "^$DBTARGET[[:blank:]]" $PSWD_FILE | awk '{print $11}'`
DB_RMAN=`sed -n '$p'  $PSWD_FILE | awk '{print $1}'`
PSWD_RMAN=`sed -n '$p'  $PSWD_FILE | awk '{print $7}'`
#PSWD_RMAN=@@

echo "BkServers:$BkServers" >> $RMAN_LOG_FILE

#echo "TZ:$TZ" >> $RMAN_LOG_FILE 
#echo "HOME:$HOME" >> $RMAN_LOG_FILE 
#echo "NB_ORA_FULL:$NB_ORA_FULL" >> $RMAN_LOG_FILE 
#echo "NB_ORA_CINC:$NB_ORA_CINC" >> $RMAN_LOG_FILE 
#echo "NB_ORA_INCR:$NB_ORA_INCR" >> $RMAN_LOG_FILE

#BK_DIR="/opt/oracle/admin/${ORACLE_SID}/backup"
#FORMATC="'${BK_DIR}/cfile_%d_%Y%M%D_s%s_p%p_%t.bk'" 
#FORMATS="'${BK_DIR}/spfile_%d_%Y%M%D_s%s_p%p_%t.bk'" 
#----------------- end Get params

#------- Check BkServers & Set Srv..
if [[ ${#BkServers} -ne 2 ]]; then
  echo "BkServers:$BkServers" >> $RMAN_LOG_FILE
  exit 1
fi
BkServers=${BkServers,,}  # convert to lowercase
BKDFParm=${BkServers:0:1}
BKALParm=${BkServers:1:1}
if [[ "$BKDFParm" == "p" ]]; then
  SrvDF=$cRolePrimary
elif [[ "$BKDFParm" == "s" ]]; then
  SrvDF=$cRoleStandby
else
  echo "BKDFParm:$BKDFParm" >> $RMAN_LOG_FILE
  exit 1
fi
if [[ "$BKALParm" == "p" ]]; then
  SrvAL=$cRolePrimary
elif [[ "$BKALParm" == "s" ]]; then
  SrvAL=$cRoleStandby
else
  echo "BKALParm:$BKALParm" >> $RMAN_LOG_FILE
  exit 1
fi
#----------------- end Check BkServers

#------- Paste Flags
NFlags=3
if [[ ${#Flags} -lt $NFlags ]]; then
  echo "Number of the Flags $Flags must be $NFlags" >> $RMAN_LOG_FILE
	exit 1
fi

#Flags=${Flags,,}
FlagValid=${Flags:0:1}
FlagDelBkAL=${Flags:1:1}
FlagDelOthAL=${Flags:2:1}

if [ "$FlagValid" -eq "1" ]; then
  VALID=VALIDATE
else
  VALID=
fi	

#------- Get DB role
CMD="
#pwd
#. ~/.profile
#db$DB
ORACLE_HOME=$ORACLE_HOME
ORACLE_SID=$ORACLE_SID
PATH=$ORACLE_HOME/bin:$PATH
export PATH ORACLE_HOME ORACLE_SID
export NLS_DATE_FORMAT=\"DD-MON-YYYY HH24:MI:SS\"
$ORACLE_HOME/bin/sqlplus -s /NOLOG <<EOF
connect / as sysdba
set termout off
set pagesize 0
set newpage none
set feedback off
set echo off

SELECT DATABASE_ROLE FROM v\\\$database;

exit
EOF
"

#echo "$CMD" >> $RMAN_LOG_FILE
DB_ROLE=`su - oracle -c "$CMD"`
DB_ROLE=${DB_ROLE//$'\n'/}

echo "DB_ROLE:$DB_ROLE" >> $RMAN_LOG_FILE

if [ "$DB_ROLE" = "$cPrimaryDB" ]; then
  ServerRole=$cRolePrimary;
elif [[ $DB_ROLE =~ "$cPhStandbyDB" ]]; then
  ServerRole=$cRoleStandby;
else
  ServerRole=$cRoleError;
  echo "Error in DB_ROLE: $DB_ROLE" >> $RMAN_LOG_FILE
	exit 1;
fi

echo "NStrmBase:$NStrmBase" >> $RMAN_LOG_FILE
echo "NStrmALog:$NStrmALog" >> $RMAN_LOG_FILE
NBaseM1=$(expr $NStrmBase - 1)
NALogM1=$(expr $NStrmALog - 1)
echo "NBaseM1:$NBaseM1" >> $RMAN_LOG_FILE
echo "NALogM1:$NALogM1" >> $RMAN_LOG_FILE

DBSERVICE=${DBTARGET} #_${CLIENT_SHORT}
#TARGET_CONNECT_STR=netbackup/${PSWD_TARGET}@${DBSERVICE}
TARGET_CONNECT_STR=${TARGET_CONNECT_STR:-"sys/manager01"}
#TARGET_CONNECT_STR="/ as sysdba"
TARGET_CONNECT_STR="/ "

#CATALOG_CONNECT_STR=rman/$PSWD_RMAN@$DB_RMAN
if [ "$DB_RMAN" != "none" ]; then
  RCAT_STR="catalog rman/$PSWD_RMAN@$DB_RMAN"
else
  #RCAT_STR="nocatalog"
  RCAT_STR=""
fi

RUN_AS_USER=oracle
RMAN=$ORACLE_HOME/bin/rman
#echo "TARGET_CONNECT_STR:$TARGET_CONNECT_STR" >> $RMAN_LOG_FILE
CUSER=`id | cut -d"(" -f2 | cut -d ")" -f1`

if [ "$NB_ORA_FULL" = "1" ]
then
    BACKUP_TYPE="INCREMENTAL LEVEL=0"
elif [ "$NB_ORA_INCR" = "1" ]
then
    BACKUP_TYPE="INCREMENTAL LEVEL=1"
elif [ "$NB_ORA_CINC" = "1" ]
then
    BACKUP_TYPE="INCREMENTAL LEVEL=1 CUMULATIVE"
elif [ "$BACKUP_TYPE" = "" ]
then
    BACKUP_TYPE="INCREMENTAL LEVEL=0"
fi

echo "BACKUP_TYPE: $BACKUP_TYPE" >> $RMAN_LOG_FILE
#------------------

#New!!!
function get_streams()
{
  local _ResultAlloc=$1
  local _ResultClose=$2
  local NStrm=$3
  local SumAlloc
  local SumClose
  local NumCh
  NL=$'\x0A'
  
  SumAlloc=""
  SumClose=""
  for ((i=1; i<=$NStrm; i++))
  do
    NumCh="ch$(printf "%02d" $i)"
		if [[ $i -eq 1 ]]; then
			SumAlloc="ALLOCATE CHANNEL $NumCh TYPE 'SBT_TAPE';"
			SumClose="RELEASE CHANNEL $NumCh;"
		else
				SumAlloc="ALLOCATE CHANNEL $NumCh TYPE 'SBT_TAPE';${NL}$SumAlloc"
				SumClose="$SumClose${NL}RELEASE CHANNEL $NumCh;"
		fi
  done
  
  eval $_ResultAlloc="'$SumAlloc'"
  eval $_ResultClose="'$SumClose'"
}
#---- end get_streams

#New!!!
function get_scn()
{
CMD="
ORACLE_HOME=$ORACLE_HOME
ORACLE_SID=$ORACLE_SID
PATH=$ORACLE_HOME/bin:$PATH
export PATH ORACLE_HOME ORACLE_SID
export NLS_DATE_FORMAT=\"DD-MON-YYYY HH24:MI:SS\"
$ORACLE_HOME/bin/sqlplus -s /NOLOG <<EOF
connect / as sysdba
set termout off
set pagesize 0
set newpage none
set feedback off
set echo off

SELECT MIN(sequence#) || '  ' ||  MAX(sequence#) || '  ' || MIN(first_change#) || '  ' || MAX(next_change#-1) 
from (
select P.FIRST_CHANGE#, P.NEXT_CHANGE#, P.SEQUENCE#, P.NAME
    from v\\\$archived_log p
    where P.DEST_ID in (SELECT dest_id from v\\\$archive_dest where dest_name LIKE 'LOG_ARCHIVE%') 
        and P.NAME is not null
        and P.APPLIED = 'YES'
        );

exit
EOF
"

echo -e "CMD-SCN:$CMD" >> $RMAN_LOG_FILE
SELECT_STR=`su - oracle -c "$CMD"`
#su - oracle -c "$CMD" >> $RMAN_LOG_FILE 2>&1
#exit
echo "SELECT_STR:$SELECT_STR" >> $RMAN_LOG_FILE

SCN0=`echo "$SELECT_STR" | awk '{print $3}'`
SCN1=`echo "$SELECT_STR" | awk '{print $4}'`
SCN0=${SCN0//$'\n'/}
SCN1=${SCN1//$'\n'/}
echo "SCN0:$SCN0" >> $RMAN_LOG_FILE
echo "SCN1:$SCN1" >> $RMAN_LOG_FILE

}
#---- end get_scn

function set_cmd()
{
  if  [[ $ServerRole -eq $SrvDF ]] || [[ $ServerRole -eq $SrvAL ]]; then 
    if [[ -z $RCAT_STR ]]; then
		#	RMAN_CATALOG="#RMAN_CATALOG"
			RMAN_CATALOG=""
		else
			RMAN_CATALOG="connect $RCAT_STR;"
		fi
	  BK_CONTROL="BACKUP $VALID FORMAT 'c_u%u_s%s_p%p_%t' CURRENT CONTROLFILE;"
  else
    RMAN_CATALOG="#RMAN_CATALOG"
	  BK_CONTROL="#BK_CONTROL"
  fi

  if [[ $ServerRole -eq $cRoleStandby ]]; then
    # Set ConfStandby
    CONF="
CONFIGURE CONTROLFILE AUTOBACKUP OFF;
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE;"

    BkCntrlCs="#BkCntrlCs"
  elif  [[ $ServerRole -eq $cRolePrimary ]]; then
    # Set ConfPrimary
    CONF="
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP OFF;
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON STANDBY;"

    BkCntrlCs="BACKUP $VALID FORMAT 'cs_u%u_s%s_p%p_%t' CURRENT CONTROLFILE FOR STANDBY;"	
  else 
    echo "Error in ServerRole: $ServerRole" >> $RMAN_LOG_FILE
    exit 20
  fi  
  
  RunDF="#RunDF"
  if [[ $SCRT_TYPE == $cCallTypeDB ]] || [[ $SCRT_TYPE == $cCallTypeDBfull ]] || [[ $SCRT_TYPE == $cCallTypeDBdiff ]]; then
    if  [[ $ServerRole -eq $SrvDF ]]; then 
  # RUN_DB="...."
  	  if [[ $NBaseM1 -gt 0 ]]; then	
          get_streams  AllocDB ReleaseDB $NBaseM1
		      SendDF=$SEND
	    else
          AllocDB="#AllocDB"
          ReleaseDB="#ReleaseDB" 
					SendDF="#SendDF"
			fi
	
      BACKUPDB="BACKUP $VALID $BACKUP_TYPE FORMAT 'bk_u%u_s%s_p%p_%t' DATABASE TAG '${CLIENT_SHORT}';"
    else
      BACKUPDB="#BACKUPDB"
    fi

    RunDF="
$AllocDB
$SendDF
$BACKUPDB
$ReleaseDB
"  
  fi

  RunAL="#RunAL"
if [[ $SCRT_TYPE == $cCallTypeAL ]]; then
  if  [[ $ServerRole -eq $SrvAL ]]; then 
  
		if  [[ $ServerRole -eq $cRolePrimary ]]; then
			AlterCurrAL="sql 'alter system archive log current';"
		else
			AlterCurrAL="#AlterCurrAL"
		fi
  
  # RUN_AL="...."
		if [ $NALogM1 -gt 0 ]; then
				get_streams  AllocAL ReleaseAL $NALogM1
				SendAL=$SEND
		else
					AllocAL="#AllocAL"
					ReleaseAL="#ReleaseAL"
					SendAL="#SendAL"	
		fi  
		
		if [[ $FlagDelBkAL -eq 1 ]]; then
		  DelBkAL="DELETE INPUT"
		else
		  DelBkAL=""
		fi
  
    RunAL="
$AlterCurrAL
$AllocAL
$SendAL
BACKUP $VALID
    FORMAT 'arch-s%s-p%p-%t'
    ARCHIVELOG
        ALL
        FILESPERSET 128
	NOT BACKED UP 2 TIMES 
	TAG '${CLIENT_SHORT}' 
	$DelBkAL;
#    DELETE INPUT; 
$ReleaseAL	
"   
  elif [[ $FlagDelOthAL -eq 1 ]]; then
  # delete_AL
    get_scn

    if [ "x$SCN1" != "x" ]; then
      #nocatalog
			RMAN_CATALOG="#RMAN_CATALOG"
      RunAL="
#DELETE NOPROMPT ARCHIVELOG UNTIL TIME 'sysdate - 0.04' DEVICE TYPE DISK BACKED UP 1 TIMES TO DEVICE TYPE 'SBT_TAPE' ;
DELETE NOPROMPT ARCHIVELOG SCN BETWEEN $SCN0 AND $SCN1 DEVICE TYPE DISK ;
"
    else
      echo "Archivelogs doesn't exist!" >> $RMAN_LOG_FILE
    fi
  fi
fi  
  
RUN="
ALLOCATE CHANNEL ch00 TYPE 'SBT_TAPE';
$SEND
$BkCntrlCs
$RunDF
$RunAL
$BK_CONTROL
RELEASE CHANNEL ch00; 
"  

CMD="
ORACLE_HOME=$ORACLE_HOME
export ORACLE_HOME
ORACLE_SID=$ORACLE_SID
export ORACLE_SID
export NLS_DATE_FORMAT=\"DD-MON-YYYY HH24:MI:SS\"
#TNS_ADMIN=/var/opt/oracle
export TNS_ADMIN=/var/opt/oracle
#export ORA_RMAN_SGA_SIZE=35M
$RMAN msglog $RMAN_LOG_FILE append <<EOF
${RMAN_CATALOG}
connect target $TARGET_CONNECT_STR;

$CONF

RUN {
$RUN
}
EOF
"
}
#---- end set_cmd

#New!!!
function do_cmd()
{
if [ "$CUSER" = "root" ]
then
    su - $RUN_AS_USER -c "$CMD" >> $RMAN_LOG_FILE 2>&1
    RSTAT=$?
else
    sh -c "$CMD" >> $RMAN_LOG_FILE
    RSTAT=$?
fi
}
#---- end do_cmd

# main

#echo "BACKUPDB:$BACKUPDB" >> $RMAN_LOG_FILE

#SEND="SEND 'NB_ORA_CLIENT=${NB_ORA_CLIENT},NB_ORA_POLICY=${NB_ORA_POLICY},NB_ORA_SERV=${NB_ORA_SERV},NB_ORA_SCHED=Default-Application-Backup';"
SEND="SEND 'NB_ORA_CLIENT=${NB_ORA_CLIENT},NB_ORA_POLICY=${NB_ORA_POLICY},NB_ORA_SERV=${NB_ORA_SERV},NB_ORA_SCHED=$SchedOut';"
echo "SEND:$SEND" >> $RMAN_LOG_FILE

echo "ServerRole:$ServerRole" >> $RMAN_LOG_FILE

BACKUPDB="#BACKUPDB0"
BkCntrlCs="#BkCntrlCs0"

# ALLOC2=
# RELEASE2= 

RunDF="#RunDF0"
RunAL="#RunAL0"  
AllocDB="#AllocDB0"
AllocAL="#AllocAL0"
ReleaseDB="#ReleaseDB0"
ReleaseAL="#ReleaseAL0"
BackupAL="#BackupAL0"
SendDF="#SendDF0"
SendAL="#SendAL0"
BK_CONTROL="#BK_CONTROL0"

#New!!!
    echo "Call set_cmd" >> $RMAN_LOG_FILE
    set_cmd

    echo "CMD:$CMD" >> $RMAN_LOG_FILE

    #exit

    echo "Call do_cmd" >> $RMAN_LOG_FILE
    do_cmd

if [ "$RSTAT" = "0" ]
then
    LOGMSG="ended successfully"
else
    LOGMSG="ended in error"
fi

echo >> $RMAN_LOG_FILE
echo Script $SCRIPT_NAME >> $RMAN_LOG_FILE
echo ==== $LOGMSG on `date` ==== >> $RMAN_LOG_FILE
echo >> $RMAN_LOG_FILE
echo >> $RMAN_LOG_FILE
echo >> $RMAN_LOG_FILE

exit $RSTAT
