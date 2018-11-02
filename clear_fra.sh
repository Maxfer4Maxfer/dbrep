#!/bin/bash
# set -e

scriptname=$(basename $0)
lock="/tmp/${scriptname}"

exec 200>$lock
flock -n 200 || exit 1
pid=$$
echo $pid 1>&200


## The code:
. ~/.bash_profile
ORACLE_SID=svcg
echo '------------------------------------------------------------------------';
echo 'Delete old archived logs at '`date`;
echo " delete noprompt archivelog all completed before 'sysdate-2'; " | rman target /

