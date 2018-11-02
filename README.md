# DBRep

DBRep is a replication tool for Oracle Database Standard Edition.
If you don't need any Oracle EE options but still need DataGuard for make a standby database then DBRep will help you.

![DBRep Overview](https://github.com/Maxfer4Maxfer/dbrep/overview.jpg)

* Replication for Oracle Standard Edition
* Replication is run be a dbrep.sh script via a crontab schedule
* A dbrep.sh automatically determine push or apply archive logs

DBRep set of couple scripts written on **bash** and **PL/SQL**. Thus DBRep can be easy modified and you can adjust it for you.

I was developed DBRep inspired by one of these [approach](http://www.dba-oracle.com/oracle_tips_failover.htm)

## Processes on the Primary database
* dbrep.sh script is excepted each 10 minutes be a crontab schedule
* dbrep.sh script determines there is primary or standby database
* Run a rsync synchronisation process of a /orafra/<SID>/archivelog folder
* Logs to a /var/log/dbrep/dbrep.log file

## Processes on the Standby database
* dbrep.sh is excepted each 10 minutes be a crontab schedule
* dbrep.sh determines there is primary or standby database
* Find new archive logs and registered them in a Standby instance
* Oracle Database automatically apply new archive log
* Logs to a /var/log/dbrep/dbrep.log file


## Getting started

You will need **rsync** and **git**

```bash
yum install -y rsync git
```

Prepare a directory for logs and set up logrotated

```bash
mkdir var/log/dbrep/
chmod 764 var/log/dbrep/
chmod 664 var/log/dbrep/*
chown -R oracle:oinstall /var/log/dbrep/

cat > /etc/logrotate.d/dbrep << 'EOF'
/var/log/dbrep/* {
	missingok
	notifempty
	copytruncate
	size 10k
	create 0664 oracle oinstall
	rotate 8
}
EOF
```

BOTH: Clone DBRep repository
```bash
su - oracle
git clone https://github.com/Maxfer4Maxfer/dbrep
```

BOTH: Set up initial variables
```bash
vi dbrep.sh
	. ~/.bash_profile
	ORACLE_SID=ORACLESID						 #ORACLE SID
	NEIGHBOR=standby_server_name				 #Standby Server
	ARCH_DIR=/orafra/ORACLESID/archivelog		#Directory with archive logs
	SETUP_DIR=/home/oracle/dbrep			 	#Directory with dbrep
```

PRIMARY: Setup a file management policy for apply archived logs on a Standby database. Should be performed on a Primary database.
```bash
su – oracle
sqlplus / as sysdba
startup
alter system set standby_file_management='AUTO' scope=both;
```

STANDBY: Drop Standby DB
```bash
su – oracle
sqlplus / as sysdba
shutdown immediate;
startup mount exclusive restrict;
drop database;
```

PRIMARY: Backup Primary DB
```bash
su – oracle
echo 'select dbid from v$database;' | sqlplus -s / as sysdba
rman target /
backup database plus archivelog;
list backup of spfile completed after 'sysdate-4/24';
list backup of controlfile completed after 'sysdate-4/24';
list backup of database completed after 'sysdate-4/24';
list backup of archivelog all;
```

PRIMARY: Transfer backup to Standby
```bash
su - oracle
DISTANATION=<STANDBY HOSTNAME>
FRADIR=/orafra
ORACLE_SID=<ORACLE_SID>
rsync -avzhP --stats --inplace --checksum --compress $DISTANATION:$FRADIR/$ORACLE_SID $FRADIR  2>&1
```

STANDBY: Restore Database on Standby

```bash
#DBID and backup files should be replaced by information received from "Backup Primary DB" step
su - oracle
rman target /
run
{
set dbid **2199354017**;
startup nomount
restore spfile from '/orafra/TEST/backupset/2016_01_18/o1_mf_ncsnf_TAG20160118T150050_c9srjwnd_.bkp';
startup force nomount
restore standby controlfile from '/orafra/TEST/backupset/2016_01_18/o1_mf_ncsnf_TAG20160118T150050_c9srjwnd_.bkp';
alter database mount;
restore database;
recover database;
}
```


STANDBY: Start Database as Standby
```bash
su - oracle
sqlplus / as sysdba
alter database recover managed standby database disconnect;
```


BOTH: Put two jobs into oracle’s crontab on both servers.

```bash
crontab -e

*/10 * * * * /home/oracle/dbrep/dbrep.sh >> /var/log/dbrep/dbrep.log 2>&1
05 2 * * * /home/oracle/dbrep/clear_fra.sh >> /var/log/dbrep/clear_fra.log 2>&1
```



## FAILOVER TO STANDBY
These commands should execute on Standby.
After you do this you will never get back easely.
Only the backup/resote procedure helps you reestablish replication.

```bash
su – oracle
sqlplus / as sysdba
alter database recover managed standby database finish;
alter database activate standby database;
alter database open;
```

## FAILBACK PROCEDURE

1.	Create Standby DB on PROD site:
•	Drop unused DB on PROD site by following “Drop Standby DB”.
•	Backup DB on DR site by following “Backup Primary DB”.
•	Transfer a created backup to PROD site “Transfer backup to Standby”.
•	Restore DB on PROD site by following “Restore Database on Standby”.
•	Setup Standby to automatically accept changes from Primary DB by following 1.8 “Start Database as Standby”.
•	Make sure that an application works this a database on PROD site.
2.	Failover DB from DR to PROD site by following  “Failover to standby”.
3.	Create Standby DB on DR site:
•	Drop unused DB on DR  site by following “Drop Standby DB”.
•	Backup DB on PROD site by following “Backup Primary DB”.
•	Transfer a created backup to DR site “Transfer backup to Standby”.
•	Restore DB on DR site by following “Restore Database on Standby”.
•	Setup Standby to automatically accept changes from Primary DB by following “Start Database as Standby”.




## Useful commands

DBRep log:
```bash
tail –f /var/log/dbrep.log
```

Database alert log:
```bash
tail -f $ORACLE_BASE/diag/rdbms/$ORACLE_SID/$ORACLE_SID/trace/alert_$ORACLE_SID.log
```

Database state and current role (Primary or Standby):
```bash
echo -e ' select open_mode,protection_mode,database_role from v$database; ' | sqlplus -s / as sysdba
```

Current Database SCN and Checkpoint number:
```bash
echo -e ' select current_scn, checkpoint_change# from v$database; ' | sqlplus -s / as sysdba
```

Checkpoint number for each datafile:
```bash
echo -e ' set linesize 132; \n column name format a55 \n select name,checkpoint_change# from v$datafile; ' | sqlplus -s / as sysdba
```

List of existed archive logs:
```bash
echo -e ' set linesize 132; \n column name format a85 \n column applied format a15 \n select sequence#,name,applied from v$archived_log where name is not null group by sequence#,applied,name order by sequence#; ' | sqlplus -s / as sysdba

echo -e ' list archivelog all; ' | rman target /
```

Delete old archive logs
```bash
echo " delete noprompt archivelog all completed before 'sysdate-1'; " | rman target /
```
