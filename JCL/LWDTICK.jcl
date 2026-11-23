//LWDTICK  JOB 'LWD TICK',CLASS=A,MSGCLASS=A,USER={{SCHEDUSER}}
//*
//* One tick of the LWD scheduler (S4): python/tick.py calls
//* POST /schedulerTicks until no more deployments are due. Schedule
//* it every few minutes with any workload scheduler (IZWS: a job
//* without dependencies, cyclic). Connect the scheduler's userid to
//* {{SCHEDGROUP}}: READ on SURROGAT {{SCHEDUSER}}.SUBMIT (JCL/RACF).
//* Then the output collector (S3): OUTLIST (LWDM940) purges output
//* older than OUTDAYS and lists the runs whose output is due,
//* OUTGET (REXX LWDR941) copies their spool with SDSF, OUTLOAD
//* (LWDM945) loads it into DB2. It runs whatever the tick did.
//* RC 0 = all OK. TICK: anything else = a tick failed or LWD could
//* not be reached; see STDOUT. BPXBATCH passes the exit status of
//* the shell, on some z/OS levels times 256. OUTLIST, OUTGET,
//* OUTLOAD: 8 = see SYSOUT and SYSTSPRT. The next run tries again.
//* Needs: tick.py, tick.sh, Globals.py and MyRequests.py in
//*   {{TICKDIR}}
//* a venv with requests in
//*   {{TICKVENV}}
//* and the configuration, readable by {{SCHEDUSER}} only (tick.py):
//*   {{TICKCONFIG}}
//* For the collector: READ on {{LOADLIB}} and
//* {{EXECLIB}}, SDSF authority and READ on the JESSPOOL
//* profile of the deployment jobs (JCL/RACF).
//*
//TICK     EXEC PGM=BPXBATCH,REGION=0M
//STDPARM  DD *
SH {{TICKDIR}}/tick.sh {{TICKCONFIG}}
/*
//STDENV   DD *
PYZ={{PYTHONHOME}}
VENV={{TICKVENV}}
/*
//STDOUT   DD SYSOUT=*
//STDERR   DD SYSOUT=*
//*
//* Output collector (S3), 1: purge, and the runs to collect
//OUTLIST  EXEC PGM=IKJEFT1B
//STEPLIB  DD DISP=SHR,DSN={{LOADLIB}}
//         DD DISP=SHR,DSN={{DB2SSHLQ}}.SDSNEXIT
//         DD DISP=SHR,DSN={{DB2HLQ}}.SDSNLOAD
//OUTLIST  DD DSN=&&OUTLIST,DISP=(NEW,PASS),SPACE=(TRK,(1,1)),
//            RECFM=FB,LRECL=80
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//SYSTSIN  DD *
 DSN SYSTEM({{DB2SSID}})
 RUN PROGRAM(LWDM940) PLAN({{DB2PLAN}})
 END
/*
//*
//* 2: their spool, copied with SDSF; up to 20 runs of OUTLINES lines
//OUTCHK   IF (OUTLIST.RC = 0) THEN
//OUTGET   EXEC PGM=IKJEFT1B,PARM='%LWDR941'
//SYSEXEC  DD DISP=SHR,DSN={{EXECLIB}}
//OUTLIST  DD DSN=&&OUTLIST,DISP=(OLD,DELETE)
//OUTDATA  DD DSN=&&OUTDATA,DISP=(NEW,PASS),
//            SPACE=(CYL,(50,50),RLSE),RECFM=VB,LRECL=304
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DUMMY
//*
//* 3: into DB2
//LOADCHK  IF (OUTGET.RC = 0) THEN
//OUTLOAD  EXEC PGM=IKJEFT1B
//STEPLIB  DD DISP=SHR,DSN={{LOADLIB}}
//         DD DISP=SHR,DSN={{DB2SSHLQ}}.SDSNEXIT
//         DD DISP=SHR,DSN={{DB2HLQ}}.SDSNLOAD
//OUTDATA  DD DSN=&&OUTDATA,DISP=(OLD,DELETE)
//SYSTSPRT DD SYSOUT=*
//SYSPRINT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//SYSTSIN  DD *
 DSN SYSTEM({{DB2SSID}})
 RUN PROGRAM(LWDM945) PLAN({{DB2PLAN}})
 END
/*
//LOADEND  ENDIF
//OUTEND   ENDIF
