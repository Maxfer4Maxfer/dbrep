#!/bin/bash
#set -x

scriptname=$(basename $0)
lock="/tmp/${scriptname}"

exec 200>$lock
flock -n 200 || exit 1
pid=$$
echo $pid 1>&200


## The code:
. ~/.bash_profile
ORACLE_SID=ORACLESID										#ORACLE SID
NEIGHBOR=standby_server_name						#Standby Server
ARCH_DIR=/orafra/ORACLESID/archivelog		#Directory with archive logs
SETUP_DIR=/home/oracle/dbrep						#Directory with dbrep

# Who am I? Prod or Standby
MY_DB_STATUS=`echo 'select database_role from v$database; ' | sqlplus -s / as sysdba | grep -E 'PRIMARY|STANDBY'`
# Who is my neighbor? Prod or Standby
NEIGHBOR_DB_STATUS=`ssh $NEIGHBOR ". ~/.bash_profile; ORACLE_SID=$ORACLE_SID; echo 'select database_role from v\\$database; ' | sqlplus -s / as sysdba | grep -E 'PRIMARY|STANDBY'"`

# Push logs to a Stanby DB
if [[ $MY_DB_STATUS == "PRIMARY" ]] &&  [[ $NEIGHBOR_DB_STATUS == "PHYSICAL STANDBY" ]]; then
	echo '------------------------------------------------------------------------';
	echo 'Synchronization started at '`date`;

	# Find out what a file is opened
	FILEINUSE=" "
	for FILE in $(find $ARCH_DIR -name *arc); do
		/sbin/fuser -s $FILE
		if [ $? -eq 0 ]; then    #if 0 then someone uses that file
			FILEINUSE=$FILE
		fi
	done

	rsync -avzhP --inplace --checksum --compress --stats --exclude='`basename $FILEINUSE 2>/dev/null`' $ARCH_DIR/ $NEIGHBOR:$ARCH_DIR 2>&1

	if [[ $FILEINUSE != " " ]]; then
		echo ''
		echo "File $FILEINUSE is not synchronized because some other process using it."
		echo ''
	fi

	echo ''
	echo 'Synchronization finished at '`date`;
fi

# Apply logs from a Primary DB
if [[ $MY_DB_STATUS == "PHYSICAL STANDBY" ]] &&  [[ $NEIGHBOR_DB_STATUS == "PRIMARY" ]]; then
	echo '------------------------------------------------------------------------';
	echo 'Apply Archived Logs. Start at '`date`

	for FILE in $(find $ARCH_DIR -name *arc); do
		/sbin/fuser -s $FILE
		if [ $? -eq 0 ]; then    #if 0 then someone uses that file
			echo "Archive log $FILE is not register in DB because some other process using it."
		else
			echo "@$SETUP_DIR/register_archlog.sql $FILE `basename $FILE`" | sqlplus -s / as sysdba;
		fi
	done

	echo ''
	echo 'Apply Archived Logs. Finish at '`date`
fi
