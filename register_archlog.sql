
-- -----------------------------------------------------------------------------------
-- Description  : Register Archived Log
-- Call Syntax  : @register_archlog.sql (full_name_with_path) (arch_name)
-- Use from CLI : echo "@ddl_roles_for_user.sql ORALCE_SID" | sqlplus -s / as sysdba
-- Version      : 1.2
-- -----------------------------------------------------------------------------------

spool register_arclog.log;

set long 20000 longchunksize 20000 pagesize 0 linesize 250 feedback off verify off trimspool on
set serveroutput on;
set sqlblanklines on;
set termout on;

declare
  v_full_name varchar2(1024) := '&1';
  v_arch_name varchar2(1024) := '&2';
  v_out_full_name varchar2(513);
  v_out_recid number;
  v_out_stamp number;
  cnt_rec    number(2);
  v_sequence varchar2(10);


begin
  -- dbms_output.put_line('v_arch_name '||v_arch_name);

  --v_sequence := substr(v_arch_name,instr(v_arch_name,'_',1,3)+1,instr(v_arch_name,'_',1,4)-instr(v_arch_name,'_',1,3)-1);
  select nvl(count(2),0) into cnt_rec
  from v$archived_log
  where
    (( name like '%'||v_arch_name ) or
    ( name like v_arch_name )) and
    ( applied = 'YES' );
    -- or ( v_sequence = sequence# );
  if cnt_rec=0 then
    dbms_output.put_line(chr(9));
    dbms_output.put_line('Registration of the acrhived log: ' || CHR(9) ||v_arch_name);
    dbms_backup_restore.inspectArchivedLog( v_full_name, v_out_full_name, v_out_recid, v_out_stamp );
    dbms_output.put_line('full_name '||CHR(9)||v_out_full_name);
    dbms_output.put_line('recid '||CHR(9)||v_out_recid);
    dbms_output.put_line('v_out_stamp '||CHR(9)||v_out_stamp);
  -- else
    -- dbms_output.put_line('Already registered');
  end if;
end;
/

set linesize 80 pagesize 14 feedback on verify on
exit
