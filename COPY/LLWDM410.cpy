          05 LLWDM410.
             10 RETURNCODE          PIC N(02).
             10 REASONCODE          PIC N(02).
             10 INFOMESSAGE         PIC N(72).
             10 TEMPLATEID          PIC S9(9) USAGE COMP-5.
             10 JCLLENGTH           PIC S9(9) USAGE COMP-5.
             10 JCL                 PIC X(32400).
             10 CHANGENOTE.
                49 CHANGENOTE-LEN PIC S9(4) USAGE COMP-5.
                49 CHANGENOTE-TEXT PIC N(255).
             10 REVISION            PIC S9(4) USAGE COMP-5.
             10 LINECOUNT           PIC S9(9) USAGE COMP-5.
             10 WARNINGCOUNT        PIC S9(4) USAGE COMP-5.
