          05 LLWDM214.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 DEPLID              PIC S9(9) USAGE COMP-5.
             10 JOBNO               PIC S9(4) USAGE COMP-5.
             10 RUN-COUNT           PIC S9(4) USAGE COMP-5.
             10 RUN-ENTRY OCCURS 20 TIMES
                  DEPENDING ON RUN-COUNT.
                15 RUNID               PIC S9(9) USAGE COMP-5.
                15 RUN-JOBNO           PIC S9(4) USAGE COMP-5.
                15 JOBNAME             PIC N(08).
                15 RUNSTATUS           PIC N.
                15 JOBRESULT           PIC N.
                15 JESJOBID            PIC N(08).
                15 SUBMITTEDDATE       PIC N(26).
                15 ENDEDDATE           PIC N(26).
                15 JOBRC               PIC S9(4) USAGE COMP-5.
                15 ABENDCODE           PIC N(05).
                15 JOBMESSAGE.
                   49 JOBMESSAGE-LEN PIC S9(4) USAGE COMP-5.
                   49 JOBMESSAGE-TEXT PIC N(72).
                15 OUTPUTSTATUS        PIC N.
