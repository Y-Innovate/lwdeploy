          05 LLWDM950.
             10 RETURNCODE         PIC N(02).
             10 REASONCODE         PIC N(02).
             10 INFOMESSAGE        PIC N(72).
             10 MAIL-OPCODE        PIC X.
                88 MAIL-PREPARE              VALUE 'P'.
                88 MAIL-NEXT                 VALUE 'N'.
                88 MAIL-SENT                 VALUE 'S'.
                88 MAIL-FAILED               VALUE 'F'.
      *      P: the settings; N: the mail after this MAILID (0 =
      *      the first); S, F: the result of this mail
             10 MAILID             PIC S9(9) USAGE COMP-5.
             10 MAIL-WRITER        PIC X(8).
             10 MAIL-CLASS         PIC X.
             10 MAIL-MAX           PIC S9(4) USAGE COMP-5.
             10 MAIL-FOUND         PIC X.
             10 MAIL-DROPPED       PIC S9(9) USAGE COMP-5.
      *      The SMTP lines of mail MAILID, in EBCDIC (CODEPAGE 037)
             10 REC-COUNT          PIC S9(4) USAGE COMP-5.
             10 REC-ENTRY OCCURS 60 TIMES.
                15 REC-LEN         PIC S9(4) USAGE COMP-5.
                15 REC             PIC X(255).
