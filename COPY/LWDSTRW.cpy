      *===============================================================*
      * LWDSTRW: Working storage for LWDSTRP, which starts a          *
      * deployment or submits one of its jobs from a CICS module.     *
      * The module sets W-ST-DEPLID, W-ST-ENVID and, for R710,        *
      * W-ST-JOBNO. Needs LWDCTXW, LWDSECW and LWDDEPW.               *
      *===============================================================*
       01 W-ST.
          05 W-ST-DEPLID     PIC S9(9) USAGE COMP-5.
          05 W-ST-ENVID      PIC S9(9) USAGE COMP-5.
          05 W-ST-JOBNO      PIC S9(4) USAGE COMP-5.
          05 W-ST-JOBNO-IND  PIC S9(4) USAGE COMP-5.
          05 W-ST-STARTED    PIC X.
          05 C-SUBMUSR       PIC N(8) VALUE N'SUBMUSR'.
          05 C-SUBMTXN       PIC N(8) VALUE N'SUBMTXN'.
