*---------------------------------------------------------------------*
* Program    : LWDA991                                                *
* Description: LWD application program for secure values with CPACF,  *
*              because ICSF is not on every system.                   *
*              R = 32 random bytes from PRNO true random (TRNG)       *
*              H = SHA-256 of INPUT-DATA(1:INPUT-LEN) with KLMD       *
*---------------------------------------------------------------------*
         TITLE 'Random bytes and SHA-256 with CPACF'
*
         COPY  ASMMSP
*
LWDA991  CEEENTRY AUTO=WORKDSA_SIZ,MAIN=NO,BASE=R11
*
         USING WORKDSA,R13
*
         L     R8,0(,R1)
         USING LLWDA991,R8
*
         MVI   LLWDA991_RC,C'1'
         MVC   LLWDA991_OUTPUT,=XL32'00'
*
         IF (CLI,LLWDA991_FUNCTION,EQ,C'R') THEN
            LA    R0,114               * PRNO function TRNG
            XR    R2,R2                * No raw entropy wanted
            XR    R3,R3
            LA    R4,LLWDA991_OUTPUT
            LA    R5,L'LLWDA991_OUTPUT
RNGLOOP     PRNO  R2,R4
            BC    1,RNGLOOP            * CC3: partial, continue
            MVI   LLWDA991_RC,C'0'
         ENDIF
*
         IF (CLI,LLWDA991_FUNCTION,EQ,C'H') THEN
            L     R5,LLWDA991_INPUTLEN
            IF (C,R5,LE,=A(L'LLWDA991_INPUT)) THEN
               MVC   SHAICV,SHA256IV
               XC    SHAMBL,SHAMBL
               LR    R4,R5
               SLL   R4,3              * Message length in bits
               ST    R4,SHAMBL+4
               LA    R0,2              * KLMD function SHA-256
               LA    R1,SHAPARM
               LA    R4,LLWDA991_INPUT
SHALOOP        KLMD  R2,R4
               BC    1,SHALOOP         * CC3: partial, continue
               MVC   LLWDA991_OUTPUT,SHAICV
               XC    SHAPARM,SHAPARM
               MVI   LLWDA991_RC,C'0'
            ENDIF
         ENDIF
*
         DROP  R8
*
         CEETERM RC=0
*
         DROP  R13
*
* End of code
*
         LTORG
*
         DS    0D
SHA256IV DC    X'6A09E667BB67AE853C6EF372A54FF53A'
         DC    X'510E527F9B05688C1F83D9AB5BE0CD19'
*
PPA                         CEEPPA
*
                            CEECAA
*
                            CEEDSA
*
WORKDSA                     DSECT
*
                            ORG   *+CEEDSASZ
*
                            DS    0D
SHAPARM                     DS    0XL40
SHAICV                      DS    XL32
SHAMBL                      DS    XL8
*
WORKDSA_SIZ                 EQU   *-WORKDSA
*
LLWDA991                    DSECT
*
LLWDA991_FUNCTION           DS    CL1
LLWDA991_RC                 DS    CL1
LLWDA991_INPUTLEN           DS    FL4
LLWDA991_INPUT              DS    CL128
LLWDA991_OUTPUT             DS    XL32
*
R0       EQU   0
R1       EQU   1
R2       EQU   2
R3       EQU   3
R4       EQU   4
R5       EQU   5
R6       EQU   6
R7       EQU   7
R8       EQU   8
R9       EQU   9
R10      EQU   10
R11      EQU   11
R12      EQU   12
R13      EQU   13
R14      EQU   14
R15      EQU   15
*
         END   LWDA991
