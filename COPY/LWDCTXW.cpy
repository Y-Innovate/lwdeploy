      *===============================================================*
      * LWDCTXW: Working storage for LWDCTXP, the user context of the *
      * DB2 modules: userid, security settings, FACILITY checks and   *
      * the roles in an application. Before R100-APP-ROLES the module *
      * sets W-APPID; before R096-CHECK-GROUP, W-GROUP; before        *
      * R099-IN-LIST, W-LIST-TABLE and W-LIST-KEY.                    *
      *===============================================================*
       01 W-CTX.
          05 W-CTX-PGM       PIC X(8) VALUE 'LWDA990'.
          05 W-SEC-PGM       PIC X(8) VALUE 'LWDA992'.
          05 W-USERID        PIC N(8).
          05 W-SQLCODE       PIC -99999.
          05 W-SQL-WHAT      PIC N(30).
          05 W-SQL-REASON    PIC N(2).
          05 W-SETKEY        PIC N(8).
          05 W-SETVALUE.
             49 W-SETVALUE-LEN  PIC S9(4) USAGE COMP-5.
             49 W-SETVALUE-TEXT PIC N(255).
          05 W-SEC-LOADED    PIC X    VALUE 'N'.
          05 W-GRPPRFX       PIC N(30).
          05 W-GRPPRFX-LEN   PIC S9(4) USAGE COMP-5.
          05 W-ADMINRES      PIC N(44).
          05 W-ADMINRES-LEN  PIC S9(4) USAGE COMP-5.
          05 W-GRPMINS       PIC S9(4) USAGE COMP-5.
          05 W-RES-NAT       PIC N(44).
          05 W-RES-LEN       PIC S9(4) USAGE COMP-5.
          05 W-RES-PTR       PIC S9(4) USAGE COMP-5.
          05 W-RES-READ      PIC X.
          05 W-IS-ADMIN      PIC X    VALUE 'N'.
          05 W-GROUP         PIC N(8).
          05 W-IN-GROUP      PIC X.
          05 W-RACFGROUP     PIC N(8).
          05 W-GROUPS-FRESH  PIC X.
          05 W-CTX-EOF       PIC X.
          05 W-APPID         PIC S9(9) USAGE COMP-5.
          05 W-APP-FOUND     PIC X.
          05 W-ACCESSGROUP   PIC N(8).
          05 W-OWNERGROUP    PIC N(8).
          05 W-IS-MEMBER     PIC X.
          05 W-IS-OWNER      PIC X.
          05 W-IS-APPROVER   PIC X.
          05 W-CAN-SEE       PIC X.
          05 W-LIST-TABLE    PIC N(8).
          05 W-LIST-KEY      PIC N(8).
          05 W-IN-LIST       PIC X.

       01 W-LLWDA990.
           COPY LLWDA990.
       01 W-LLWDA992.
           COPY LLWDA992.

       01 C-CODES.
          05 C-BLANK      PIC N VALUE N' '.
          05 C-A          PIC N VALUE N'A'.
          05 C-C          PIC N VALUE N'C'.
          05 C-D          PIC N VALUE N'D'.
          05 C-E          PIC N VALUE N'E'.
          05 C-F          PIC N VALUE N'F'.
          05 C-H          PIC N VALUE N'H'.
          05 C-J          PIC N VALUE N'J'.
          05 C-K          PIC N VALUE N'K'.
          05 C-N          PIC N VALUE N'N'.
          05 C-O          PIC N VALUE N'O'.
          05 C-Q          PIC N VALUE N'Q'.
          05 C-R          PIC N VALUE N'R'.
          05 C-S          PIC N VALUE N'S'.
          05 C-T          PIC N VALUE N'T'.
          05 C-U          PIC N VALUE N'U'.
          05 C-W          PIC N VALUE N'W'.
          05 C-X          PIC N VALUE N'X'.
          05 C-Y          PIC N VALUE N'Y'.
          05 C-RACFGRP    PIC N(8) VALUE N'RACFGRP'.
          05 C-DEPLUSER   PIC N(8) VALUE N'DEPLUSER'.
          05 C-SETTINGS   PIC N(8) VALUE N'SETTINGS'.
          05 C-GRPPRFX    PIC N(8) VALUE N'GRPPRFX'.
          05 C-ADMINRES   PIC N(8) VALUE N'ADMINRES'.
          05 C-GRPMINS    PIC N(8) VALUE N'GRPMINS'.

       01 ERROR-MESSAGE.
          05 ERROR-LEN    PIC S9(4) COMP
                                     VALUE +720.
          05 ERROR-TEXT   PIC X(72) OCCURS 10 TIMES
                INDEXED BY ERROR-INDEX.
       77 ERROR-TEXT-LEN  PIC S9(9) COMP
                                     VALUE +72.
