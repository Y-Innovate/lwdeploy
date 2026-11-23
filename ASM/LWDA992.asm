*---------------------------------------------------------------------*
* Program    : LWDA992                                                *
* Description: LWD application program that checks whether the CICS  *
*              userid has READ access to a resource, with EXEC CICS   *
*              QUERY SECURITY, for the DB2 modules, which have no     *
*              CICS translator. Used for the FACILITY profiles of the *
*              RACF groups (M7) and the administrator resource (M5).  *
*              NOLOG: no access is an answer, not a security event.   *
*              CANREAD = Y  READ access                               *
*              CANREAD = N  no access, or not in CICS                 *
*              NOTFND (no profile protects the resource) means no     *
*              access too: a RACF group without a FACILITY profile    *
*              has no members, it must not fail the request.          *
*              RETURNCODE 08 90 when not in CICS or the command       *
*              failed; RESIDLEN must be 1-44.                         *
*---------------------------------------------------------------------*
         TITLE 'Check READ access with QUERY SECURITY'
*
         COPY  ASMMSP
*
DFHEIBR  EQU   R9
*
         COPY  DFHEIBLK
*
LWDA992  CEEENTRY AUTO=WORKDSA_SIZ,MAIN=NO,BASE=R11
*
         USING WORKDSA,R13
*
         ST    R1,PARML_PTR
*
         CALL  CEEGTST,(=A(0),=A(WORKSIZE),WORKAREA_PTR,FC0),VL,       X
               MF=(E,WORK)
*
         IF (CLC,FC0(8),NE,=XL8'0000000000000000') THEN
            L     R2,=A(12)
            B     LWDA992_RET_IMMED
         ENDIF
*
         L     R10,WORKAREA_PTR
         USING WORKAREA,R10
*
         L     R8,PARML_PTR
         L     R8,0(,R8)
         USING LLWDA992,R8
*
         MVC   LLWDA992_RETURNCODE,=CU'00'
         MVC   LLWDA992_REASONCODE,=CU'00'
         XR    R0,R0
         XR    R1,R1
         LA    R2,LLWDA992_INFOMESSAGE
         LA    R3,L'LLWDA992_INFOMESSAGE
         MVCLU R2,R0,X'020'
         MVI   LLWDA992_CANREAD,C'N'
*
         XR    R7,R7
         L     R7,548(,R7)             * Point to ASCB
         L     R7,ASCBXTCB-ASCB(,R7)   * Point to TCB
         L     R7,TCBJSCB-TCB(,R7)     * Point to JSCB
         IF (CLC,JSCBPGMN-IEZJSCB(8,R7),NE,=CL8'DFHSIP') THEN
            MVC   LLWDA992_RETURNCODE,=CU'08'
            MVC   LLWDA992_REASONCODE,=CU'90'
            MVC   LLWDA992_INFOMESSAGE(L'MSGNOCICS),MSGNOCICS
            B     LWDA992_RET
         ENDIF
*
         L     R2,LLWDA992_RESIDLEN
         IF (LTR,R2,R2,NP),OR,(C,R2,GT,=A(L'LLWDA992_RESID)) THEN
            MVC   LLWDA992_RETURNCODE,=CU'08'
            MVC   LLWDA992_REASONCODE,=CU'90'
            MVC   LLWDA992_INFOMESSAGE(L'MSGLEN),MSGLEN
            B     LWDA992_RET
         ENDIF
*
         EXEC CICS ADDRESS EIB(DFHEIBR)
*
         XC    WREAD,WREAD
         EXEC CICS QUERY SECURITY RESCLASS(LLWDA992_RESCLASS)          X
               RESID(LLWDA992_RESID) RESIDLENGTH(LLWDA992_RESIDLEN)    X
               LOGMESSAGE(DFHVALUE(NOLOG)) READ(WREAD) NOHANDLE
*
         IF (CLC,EIBRESP,EQ,=A(RESPNOTFND)) THEN
*           No profile: no access, CANREAD stays N
         ELSEIF (CLC,EIBRESP,NE,=F'0') THEN
            MVC   LLWDA992_RETURNCODE,=CU'08'
            MVC   LLWDA992_REASONCODE,=CU'90'
            MVC   LLWDA992_INFOMESSAGE(L'MSGFAIL),MSGFAIL
         ELSE
            IF (CLC,WREAD,EQ,=A(READABLE)) THEN
               MVI   LLWDA992_CANREAD,C'Y'
            ENDIF
         ENDIF
*
         DROP  R8
*
LWDA992_RET EQU   *
         XR    R2,R2
*
         CALL  CEEFRST,(WORKAREA_PTR,FC0),VL,MF=(E,WORK)
*
LWDA992_RET_IMMED EQU   *
         CEETERM RC=(R2)
*
         DROP  R10,R13
*
* End of code
*
         LTORG
*
READABLE EQU   35                      * CVDA READABLE
RESPNOTFND EQU 13                      * DFHRESP(NOTFND)
MSGNOCICS DC   CU'LWDA992 runs in CICS only'
MSGLEN   DC    CU'LWDA992 RESIDLEN must be 1-44'
MSGFAIL  DC    CU'QUERY SECURITY failed'
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
PARML_PTR                   DS    A
WORKAREA_PTR                DS    A
FC0                         DS    3A
WORK                        DS    4A
*
WORKDSA_SIZ                 EQU   *-WORKDSA
*
WORKAREA                    DSECT
*
WREAD                       DS    F
*
                            DS    0F
DFHEIPL                     DS    13F
                            DS    51F
DFHEITP1                    DS    F
*
WORKSIZE                    EQU   *-WORKAREA
*
LLWDA992                    DSECT
*
LLWDA992_RETURNCODE         DS    CUL4
LLWDA992_REASONCODE         DS    CUL4
LLWDA992_INFOMESSAGE        DS    CUL144
LLWDA992_RESCLASS           DS    CL8
LLWDA992_RESID              DS    CL44
LLWDA992_RESIDLEN           DS    FL4
LLWDA992_CANREAD            DS    CL1
*
         PUSH  PRINT
         PRINT OFF
         IHAASCB DSECT=YES
         IKJTCB DSECT=YES
         IEZJSCB
         POP   PRINT
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
         END   LWDA992
