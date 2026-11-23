      *===============================================================*
      * LWDDEPW: Working storage for LWDDEPP: new runs and history    *
      * events of a deployment, shared by the CICS modules and the    *
      * result step. Needs LWDCTXW and, for a run with a token,       *
      * LWDSECW.                                                      *
      *===============================================================*
       01 W-DEP.
          05 C-B36           PIC N(36) VALUE
             N'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
          05 C-JOBPRFX       PIC N(8) VALUE N'JOBPRFX'.
          05 W-RUN-DEPLID    PIC S9(9) USAGE COMP-5.
          05 W-RUN-JOBNO     PIC S9(4) USAGE COMP-5.
          05 W-RUN-ID        PIC S9(9) USAGE COMP-5.
          05 W-RUN-JOBNAME   PIC N(8).
          05 W-RUN-WITH-TOKEN PIC X.
          05 W-RUN-HASH-IND  PIC S9(4) USAGE COMP-5.
          05 W-RUN-NUM       PIC S9(9) USAGE COMP-5.
          05 W-RUN-DIG       PIC S9(4) USAGE COMP-5.
          05 W-RUN-I         PIC S9(4) USAGE COMP-5.
          05 W-EV-DEPLID     PIC S9(9) USAGE COMP-5.
          05 W-EV-TYPE       PIC N.
          05 W-EV-JOBNO      PIC S9(4) USAGE COMP-5.
          05 W-EV-JOBNO-IND  PIC S9(4) USAGE COMP-5 VALUE -1.
          05 W-EV-COMMENT.
             49 W-EV-COMMENT-LEN  PIC S9(4) USAGE COMP-5.
             49 W-EV-COMMENT-TEXT PIC N(255).
          05 W-EV-COMMENT-IND PIC S9(4) USAGE COMP-5 VALUE -1.
          05 W-FAIL-RUNSTATUS PIC N.
          05 W-FAIL-RESULT   PIC N.
          05 W-FAIL-MSG.
             49 W-FAIL-MSG-LEN  PIC S9(4) USAGE COMP-5.
             49 W-FAIL-MSG-TEXT PIC N(72).
          05 W-FAIL-ENVID    PIC S9(9) USAGE COMP-5.
          05 W-OK-DEPLID     PIC S9(9) USAGE COMP-5.
          05 W-OK-ENVID      PIC S9(9) USAGE COMP-5.
          05 W-OK-VERSIONID  PIC S9(9) USAGE COMP-5.
       01 W-RUN-HASH        USAGE SQL TYPE IS BINARY(32).
