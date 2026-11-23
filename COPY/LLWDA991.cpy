          05 LLWDA991.
             10 FUNCTION-CODE      PIC X.
                88 FUNC-RANDOM               VALUE 'R'.
                88 FUNC-SHA256               VALUE 'H'.
             10 A991-RC            PIC X.
                88 A991-OK                   VALUE '0'.
             10 INPUT-LEN          PIC S9(9) USAGE COMP-5.
             10 INPUT-DATA         PIC X(128).
             10 OUTPUT-DATA        PIC X(32).
