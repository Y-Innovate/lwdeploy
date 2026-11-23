          05 LLWDM212.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 DEPLID              PIC S9(9) USAGE COMP-5.
             10 JOB-COUNT           PIC S9(4) USAGE COMP-5.
             10 JOB-ENTRY OCCURS 20 TIMES
                  DEPENDING ON JOB-COUNT.
                15 JOBNO               PIC S9(4) USAGE COMP-5.
                15 JOBTITLE.
                   49 JOBTITLE-LEN PIC S9(4) USAGE COMP-5.
                   49 JOBTITLE-TEXT PIC N(60).
                15 TEMPLATEID          PIC S9(9) USAGE COMP-5.
                15 TEMPLATEREV         PIC S9(4) USAGE COMP-5.
                15 MAXRC               PIC S9(4) USAGE COMP-5.
                15 JOBSTATUS           PIC N.
                15 LINECOUNT           PIC S9(9) USAGE COMP-5.
                15 LASTRUNID           PIC S9(9) USAGE COMP-5.
                15 RUNSTATUS           PIC N.
                15 JOBRESULT           PIC N.
                15 JOBRC               PIC S9(4) USAGE COMP-5.
                15 ABENDCODE           PIC N(05).
                15 SKIPREASON.
                   49 SKIPREASON-LEN PIC S9(4) USAGE COMP-5.
                   49 SKIPREASON-TEXT PIC N(255).
