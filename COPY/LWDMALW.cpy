      *===============================================================*
      * LWDMALW: Working storage for LWDMALP, which queues the        *
      * notification mails of a history event (S5). Needs LWDCTXW and *
      * LWDDEPW (W-EV-DEPLID, W-EV-TYPE).                             *
      *===============================================================*
       01 W-ML.
          05 C-MAILWRTR      PIC N(8) VALUE N'MAILWRTR'.
          05 C-MAILURL       PIC N(8) VALUE N'MAILURL'.
      *   Space: not looked up yet; Y: mail is on; N: MAILWRTR empty
          05 W-ML-ON         PIC X VALUE SPACE.
          05 W-ML-URL.
             49 W-ML-URL-LEN  PIC S9(4) USAGE COMP-5.
             49 W-ML-URL-TEXT PIC N(255).
          05 W-ML-TYPE       PIC N.
          05 W-ML-STATUS     PIC N.
          05 W-ML-APPCODE    PIC N(8).
          05 W-ML-ENVCODE    PIC N(8).
          05 W-ML-VERSION.
             49 W-ML-VERSION-LEN  PIC S9(4) USAGE COMP-5.
             49 W-ML-VERSION-TEXT PIC N(30).
          05 W-ML-REQBY      PIC N(8).
          05 W-ML-APRGRP     PIC N(8).
          05 W-ML-APRGRP-IND PIC S9(4) USAGE COMP-5.
          05 W-ML-OWNGRP     PIC N(8).
      *   Who gets the mail: the approvers, the requester, the owners
          05 W-ML-TO-APR     PIC X.
          05 W-ML-TO-REQ     PIC X.
          05 W-ML-TO-OWN     PIC X.
          05 W-ML-WHAT       PIC N(30).
          05 W-ML-DEPLID-ED  PIC Z(8)9.
          05 W-ML-PTR        PIC S9(4) USAGE COMP-5.
          05 C-ML-LF         PIC N VALUE NX'000A'.
          05 W-ML-SUBJECT.
             49 W-ML-SUBJECT-LEN  PIC S9(4) USAGE COMP-5.
             49 W-ML-SUBJECT-TEXT PIC N(100).
          05 W-ML-BODY.
             49 W-ML-BODY-LEN  PIC S9(4) USAGE COMP-5.
             49 W-ML-BODY-TEXT PIC N(1000).
