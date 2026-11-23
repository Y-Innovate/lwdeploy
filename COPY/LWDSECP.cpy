      *===============================================================*
      * R800-NEW-TOKEN: A random job token in W-TOKEN, 64 hex digits  *
      *===============================================================*
       R800-NEW-TOKEN SECTION.
           SET FUNC-RANDOM TO TRUE
           CALL W-A991-PGM USING W-LLWDA991

           IF A991-OK
              PERFORM VARYING W-SEC-I FROM 1 BY 1 UNTIL W-SEC-I > 32
                 MOVE OUTPUT-DATA OF W-LLWDA991(W-SEC-I:1) TO W-SEC-BYTE
                 COMPUTE W-SEC-J = 2 * W-SEC-I - 1
                 COMPUTE W-SEC-K = W-SEC-BYTE-NUM / 16 + 1
                 MOVE C-HEX(W-SEC-K:1)
                   TO W-TOKEN(W-SEC-J:1)
                 MOVE C-HEX(FUNCTION MOD(W-SEC-BYTE-NUM, 16) + 1:1)
                   TO W-TOKEN(W-SEC-J + 1:1)
              END-PERFORM
           END-IF
           .
       R800-NEW-TOKEN-END.
           EXIT.

      *===============================================================*
      * R810-HASH: W-TOKENHASH, the SHA-256 of W-TOKEN, which is what *
      * JOBRUNS.JOBHASH stores                                        *
      *===============================================================*
       R810-HASH SECTION.
           SET FUNC-SHA256 TO TRUE
           MOVE 66 TO INPUT-LEN OF W-LLWDA991
           MOVE SPACES TO INPUT-DATA OF W-LLWDA991
           STRING 'J:' W-TOKEN DELIMITED BY SIZE
             INTO INPUT-DATA OF W-LLWDA991
           CALL W-A991-PGM USING W-LLWDA991

           IF A991-OK
              MOVE OUTPUT-DATA OF W-LLWDA991 TO W-TOKENHASH
           END-IF
           .
       R810-HASH-END.
           EXIT.
