       IDENTIFICATION DIVISION.
       PROGRAM-ID. LWDU981.
      *===============================================================*
      * This program is a utility of the LWD application, without     *
      * CICS or DB2, so CICS and batch programs can both call it.     *
      * Base64 (RFC 4648, with = padding) of a byte string:           *
      *   E = encode P-INPUT(1:U981-INPUT-LEN) into P-OUTPUT          *
      *   D = decode it; spaces and line ends in the input are        *
      *       skipped, as a browser may break long fields into lines  *
      * The base64 characters are EBCDIC (CODEPAGE 037): LWW converts *
      * the field to and from UTF-8, and the alphabet is the same in  *
      * both. The bytes themselves are not converted: for LWD they    *
      * are UTF-8 text.                                               *
      * Call: CALL 'LWDU981' USING LLWDU981 P-INPUT P-OUTPUT          *
      * ------------------------------------------------------------- *
      * U981-RC:                                                      *
      *   00 = OK, U981-OUTPUT-LEN is the length of the result        *
      *   04 = the result doesn't fit in U981-OUTPUT-MAX              *
      *   08 = invalid input: a character outside the alphabet, a     *
      *        wrong length, or an invalid OPCODE                     *
      * ------------------------------------------------------------- *
      * Updates:                                                      *
      *                                                               *
      * Date     Who What                                             *
      * -------- --- ------------------------------------------------ *
      * yy/mm/dd ii  description                                      *
      *===============================================================*

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WORK.
          05 C-ALPHABET  PIC X(64) VALUE
             'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz012345
      -      '6789+/'.
          05 C-PAD       PIC X     VALUE '='.
          05 W-INIT      PIC X     VALUE 'N'.
          05 W-DEC-TAB.
             10 W-DEC    PIC S9(4) USAGE COMP-5 OCCURS 256 TIMES.
          05 W-I         PIC S9(9) USAGE COMP-5.
          05 W-O         PIC S9(9) USAGE COMP-5.
          05 W-K         PIC S9(9) USAGE COMP-5.
          05 W-N         PIC S9(9) USAGE COMP-5.
          05 W-T         PIC S9(9) USAGE COMP-5.
          05 W-B1        PIC S9(9) USAGE COMP-5.
          05 W-B2        PIC S9(9) USAGE COMP-5.
          05 W-B3        PIC S9(9) USAGE COMP-5.
          05 W-NEED      PIC S9(9) USAGE COMP-5.
          05 W-QUAD.
             10 W-Q      PIC S9(4) USAGE COMP-5 OCCURS 4 TIMES.
          05 W-QN        PIC S9(4) USAGE COMP-5.
          05 W-PADS      PIC S9(4) USAGE COMP-5.
          05 W-V         PIC S9(4) USAGE COMP-5.
          05 W-CHAR      PIC X.

       LINKAGE SECTION.
       01 P-LLWDU981.
           COPY LLWDU981.
       01 P-INPUT         PIC X(65535).
       01 P-OUTPUT        PIC X(65535).

       PROCEDURE DIVISION USING P-LLWDU981 P-INPUT P-OUTPUT.
       MAIN SECTION.
           MOVE '00' TO U981-RC
           MOVE 0 TO U981-OUTPUT-LEN

           IF W-INIT = 'N'
              PERFORM R010-INIT-TABLE
           END-IF

           EVALUATE TRUE
           WHEN U981-ENCODE
              PERFORM R100-ENCODE
           WHEN U981-DECODE
              PERFORM R200-DECODE
           WHEN OTHER
              MOVE '08' TO U981-RC
           END-EVALUATE
           .
       MAIN-END.
           GOBACK.

      *===============================================================*
      * R010-INIT-TABLE: Value of each byte as a base64 digit, -1 for *
      * bytes outside the alphabet                                    *
      *===============================================================*
       R010-INIT-TABLE SECTION.
           PERFORM VARYING W-K FROM 1 BY 1 UNTIL W-K > 256
              MOVE -1 TO W-DEC(W-K)
           END-PERFORM

           PERFORM VARYING W-K FROM 1 BY 1 UNTIL W-K > 64
              COMPUTE W-N = FUNCTION ORD(C-ALPHABET(W-K:1))
              COMPUTE W-DEC(W-N) = W-K - 1
           END-PERFORM

           MOVE 'Y' TO W-INIT
           .
       R010-INIT-TABLE-END.
           EXIT.

      *===============================================================*
      * R100-ENCODE: Three bytes become four characters               *
      *===============================================================*
       R100-ENCODE SECTION.
           COMPUTE W-NEED = (U981-INPUT-LEN + 2) / 3 * 4

           IF W-NEED > U981-OUTPUT-MAX
              MOVE '04' TO U981-RC
           ELSE
              MOVE 1 TO W-I
              MOVE 0 TO W-O
              PERFORM UNTIL W-I > U981-INPUT-LEN
                 COMPUTE W-B1 = FUNCTION ORD(P-INPUT(W-I:1)) - 1
                 MOVE 0 TO W-B2 W-B3
                 MOVE 2 TO W-PADS
                 IF W-I + 1 <= U981-INPUT-LEN
                    COMPUTE W-B2 = FUNCTION ORD(P-INPUT(W-I + 1:1)) - 1
                    MOVE 1 TO W-PADS
                 END-IF
                 IF W-I + 2 <= U981-INPUT-LEN
                    COMPUTE W-B3 = FUNCTION ORD(P-INPUT(W-I + 2:1)) - 1
                    MOVE 0 TO W-PADS
                 END-IF

                 COMPUTE W-N = W-B1 * 65536 + W-B2 * 256 + W-B3

                 COMPUTE W-K = W-N / 262144 + 1
                 MOVE C-ALPHABET(W-K:1) TO P-OUTPUT(W-O + 1:1)
                 COMPUTE W-T = W-N / 4096
                 COMPUTE W-K = FUNCTION MOD(W-T, 64) + 1
                 MOVE C-ALPHABET(W-K:1) TO P-OUTPUT(W-O + 2:1)
                 COMPUTE W-T = W-N / 64
                 COMPUTE W-K = FUNCTION MOD(W-T, 64) + 1
                 MOVE C-ALPHABET(W-K:1) TO P-OUTPUT(W-O + 3:1)
                 COMPUTE W-K = FUNCTION MOD(W-N, 64) + 1
                 MOVE C-ALPHABET(W-K:1) TO P-OUTPUT(W-O + 4:1)

                 IF W-PADS >= 1
                    MOVE C-PAD TO P-OUTPUT(W-O + 4:1)
                 END-IF
                 IF W-PADS = 2
                    MOVE C-PAD TO P-OUTPUT(W-O + 3:1)
                 END-IF

                 ADD 3 TO W-I
                 ADD 4 TO W-O
              END-PERFORM

              MOVE W-O TO U981-OUTPUT-LEN
           END-IF
           .
       R100-ENCODE-END.
           EXIT.

      *===============================================================*
      * R200-DECODE: Four characters become three bytes, or fewer at  *
      * the end with padding                                          *
      *===============================================================*
       R200-DECODE SECTION.
           MOVE 0 TO W-O
           MOVE 0 TO W-QN
           MOVE 0 TO W-PADS

           PERFORM VARYING W-I FROM 1 BY 1
                     UNTIL W-I > U981-INPUT-LEN
                        OR U981-RC NOT = '00'
              MOVE P-INPUT(W-I:1) TO W-CHAR
              EVALUATE TRUE
      *       Space, CR, LF and NL (EBCDIC 40, 0D, 25, 15) are skipped
              WHEN W-CHAR = SPACE
              WHEN W-CHAR = X'0D'
              WHEN W-CHAR = X'25'
              WHEN W-CHAR = X'15'
                 CONTINUE
              WHEN W-CHAR = C-PAD
                 ADD 1 TO W-PADS
                 ADD 1 TO W-QN
                 MOVE 0 TO W-Q(W-QN)
              WHEN W-PADS > 0
      *          Nothing but padding may follow padding
                 MOVE '08' TO U981-RC
              WHEN OTHER
                 COMPUTE W-K = FUNCTION ORD(W-CHAR)
                 MOVE W-DEC(W-K) TO W-V
                 IF W-V < 0
                    MOVE '08' TO U981-RC
                 ELSE
                    ADD 1 TO W-QN
                    MOVE W-V TO W-Q(W-QN)
                 END-IF
              END-EVALUATE

              IF W-QN = 4 AND U981-RC = '00'
                 PERFORM R210-QUAD
              END-IF
           END-PERFORM

           IF U981-RC = '00' AND W-QN NOT = 0
              MOVE '08' TO U981-RC
           END-IF

           IF U981-RC = '00'
              MOVE W-O TO U981-OUTPUT-LEN
           END-IF
           .
       R200-DECODE-END.
           EXIT.

      *===============================================================*
      * R210-QUAD: Write the bytes of one group of four characters    *
      *===============================================================*
       R210-QUAD SECTION.
           IF W-PADS > 2
              MOVE '08' TO U981-RC
           ELSE
              IF W-O + 3 - W-PADS > U981-OUTPUT-MAX
                 MOVE '04' TO U981-RC
              ELSE
                 COMPUTE W-N = W-Q(1) * 262144 + W-Q(2) * 4096
                             + W-Q(3) * 64 + W-Q(4)
                 COMPUTE W-B1 = W-N / 65536
                 COMPUTE W-T = W-N / 256
                 COMPUTE W-B2 = FUNCTION MOD(W-T, 256)
                 COMPUTE W-B3 = FUNCTION MOD(W-N, 256)

                 MOVE FUNCTION CHAR(W-B1 + 1) TO P-OUTPUT(W-O + 1:1)
                 ADD 1 TO W-O
                 IF W-PADS < 2
                    MOVE FUNCTION CHAR(W-B2 + 1) TO P-OUTPUT(W-O + 1:1)
                    ADD 1 TO W-O
                 END-IF
                 IF W-PADS < 1
                    MOVE FUNCTION CHAR(W-B3 + 1) TO P-OUTPUT(W-O + 1:1)
                    ADD 1 TO W-O
                 END-IF
              END-IF
           END-IF

           MOVE 0 TO W-QN
           .
       R210-QUAD-END.
           EXIT.

       END PROGRAM LWDU981.
