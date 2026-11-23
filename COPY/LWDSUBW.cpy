      *===============================================================*
      * LWDSUBW: Working storage for LWDSUBP, which starts the task   *
      * that submits a run. The module fills in W-LLWDC910: RUNID,    *
      * the job token and the submit userid and transaction.          *
      *===============================================================*
       01 W-SUBMIT.
          05 C-CHNL-NAME-SUBMIT PIC X(16) VALUE 'LWDSUBMIT'.
          05 C-CONT-NAME-SUBMIT PIC X(16) VALUE 'LLWDC911'.
       01 W-LLWDM910.
           COPY LLWDM910.
       01 W-LLWDC910.
           COPY LLWDC910.
       01 W-LLWDC911.
           COPY LLWDC911.
