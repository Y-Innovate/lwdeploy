//LWDRACF  JOB 'RACF',CLASS=A,MSGCLASS=A,NOTIFY=&SYSUID
//*
//* Needs to exist already: group {{USERGROUP}} (everyone who uses
//* LWD) and the groups of the demo application: {{DEMOACCESSGROUP}},
//* {{DEMOOWNERGROUP}} and {{DEMOAPPROVERGROUP}}; and group
//* {{SCHEDGROUP}}, whose members may act as {{SCHEDUSER}}.
//* Creates the DB2 group {{DB2GROUP}}, the submit userid
//* {{SUBMITUSER}}, the deploy userid {{DEPLOYUSER}} and the
//* scheduler's userid {{SCHEDUSER}}, all protected (NOPASSWORD) and
//* connected to {{DB2GROUP}}. Groups, userids, connects, profiles
//* and members that exist already are left alone, without messages
//* (rdef, addmem, addgroup, adduser, connect at the end). Run it
//* again at any time. {{DEPLOYUSER}} stays protected: the result
//* step signs in to Entra with its certificate (docs/12).
//* A deploy userid that got a passphrase for the PassTickets of
//* iteration 4: ALTUSER ... NOPASSWORD by hand, once no job of before
//* iteration 8 runs any more.
//* {{DEPLOYUSER}} gets a certificate with a private key on a key ring
//* of its own, both named {{DEPLOYUSER}}, when it has none (below).
//* Upload the certificate to its Entra application afterwards. The
//* submitter needs authority for RACDCERT for other userids.
//* {{SCHEDUSER}} gets an OMVS segment
//* with AUTOUID (needs BPX.NEXT.USER), for the BPXBATCH step of
//* LWDTICK; in LWW, map the Entra application of the tick to it.
//* {{DEPLOYUSER}} gets one too, with AUTOUID, also when it existed
//* already: the result step's web enablement toolkit (LWDR916)
//* opens its sockets through z/OS UNIX. And READ on CRYPTOZ
//* CLEARKEY.SYSTOK-SESSION-ONLY, for its TLS session (below).
//* {{DEPLOYUSER}} needs READ on {{EXECLIB}} and on the jars
//* in {{JWTJARS}} (the result step), and whatever the
//* deployment jobs themselves need: not given here. {{SCHEDUSER}}
//* needs READ on {{LOADLIB}} and on
//* {{EXECLIB}}, and SDSF authority to the ST panel and
//* to browse output (LWDTICK, output collector): not given here
//* either, as sites protect SDSF differently.
//* DB2 is RACF controlled: access to the plan is given here and not
//* with GRANT. The packages use static SQL, so nobody needs access to
//* the tables. Uses the multi-subsystem scope class MDSNPN.
//* PERMIT of an access that is there already changes nothing.
//*
//STEP001 EXEC PROC=BATREXX
//COPY.SYSUT1 DD *,DLM=$$
/* REXX */
/* The DB2 group: its members may use the plan (MDSNPN, below)        */
CALL addgroup "{{DB2GROUP}}"

/* The submit and deploy userids: no special authority, both        */
/* protected. CONNECT covers userids that existed before this job.   */
CALL adduser "{{SUBMITUSER}}", "NAME('LWD SUBMIT TASK')" || ,
            " DFLTGRP({{DB2GROUP}}) NOPASSWORD NOOIDCARD"
CALL connect "{{SUBMITUSER}}", "{{DB2GROUP}}"
CALL adduser "{{DEPLOYUSER}}", "NAME('LWD DEPLOY USERID')" || ,
            " DFLTGRP({{DB2GROUP}}) NOPASSWORD NOOIDCARD" || ,
            " OMVS(AUTOUID HOME('/') PROGRAM('/bin/sh'))"
CALL connect "{{DEPLOYUSER}}", "{{DB2GROUP}}"
/* A deploy userid of before iteration 4 has no OMVS segment yet;   */
/* the result step needs one (z/OS UNIX sockets). Only when it has  */
/* no UID, so an existing UID stays.                                 */
x = OUTTRAP('lu.')
ADDRESS TSO "LISTUSER {{DEPLOYUSER}} OMVS NORACF"
x = OUTTRAP('OFF')
hasuid = 0
DO i = 1 TO lu.0
   IF POS('UID=', lu.i) > 0 THEN hasuid = 1
END
IF \hasuid THEN
   ADDRESS TSO "ALTUSER {{DEPLOYUSER}}" || ,
               " OMVS(AUTOUID HOME('/') PROGRAM('/bin/sh'))"
CALL adduser "{{SCHEDUSER}}", "NAME('LWD SCHEDULER')" || ,
            " DFLTGRP({{DB2GROUP}}) NOPASSWORD NOOIDCARD" || ,
            " OMVS(AUTOUID HOME('{{TICKHOME}}') PROGRAM('/bin/sh'))"
CALL connect "{{SCHEDUSER}}", "{{DB2GROUP}}"

CALL rdef "FACILITY", "DFHDB2.AUTHTYPE.{{CICSTXN_PUBLIC}}"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_PUBLIC}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{CICSDFLTUSER}},{{USERGROUP}},{{ADMINGROUP}}," || ,
            "{{CICSREGIONUSER}})"
CALL rdef "FACILITY", "DFHDB2.AUTHTYPE.{{CICSTXN_USER}}"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_USER}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{USERGROUP}},{{ADMINGROUP}},{{CICSREGIONUSER}})"
CALL rdef "FACILITY", "DFHDB2.AUTHTYPE.{{CICSTXN_ADMIN}}"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_ADMIN}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{ADMINGROUP}},{{CICSREGIONUSER}})"
CALL rdef "FACILITY", "DFHDB2.AUTHTYPE.{{CICSTXN_SCHED}}"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_SCHED}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{SCHEDUSER}},{{CICSREGIONUSER}})"
CALL rdef "FACILITY", "DFHDB2.AUTHTYPE.{{CICSTXN_RESULT}}"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_RESULT}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{DEPLOYUSER}},{{CICSREGIONUSER}})"
CALL rdef "FACILITY", "DFHDB2.AUTHTYPE.{{CICSTXN_SUBMIT}}"
ADDRESS TSO "PE DFHDB2.AUTHTYPE.{{CICSTXN_SUBMIT}}" || ,
            " CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{SUBMITUSER}},{{CICSREGIONUSER}})"

/* Transactions. The CICS default userid gets none of them: LWD has  */
/* no anonymous paths.                                                */
/* The web UI's files before sign-in, also for signed-in users       */
CALL rdef "GCICSTRN", "LWDPUB"
CALL addmem "GCICSTRN", "LWDPUB", "{{CICSTXN_PUBLIC}}"
ADDRESS TSO "PE LWDPUB CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{CICSDFLTUSER}},{{USERGROUP}},{{ADMINGROUP}})"

CALL rdef "GCICSTRN", "LWDUSR"
CALL addmem "GCICSTRN", "LWDUSR", "{{CICSTXN_USER}}"
ADDRESS TSO "PE LWDUSR CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{USERGROUP}},{{ADMINGROUP}})"

CALL rdef "GCICSTRN", "LWDADM"
CALL addmem "GCICSTRN", "LWDADM", "{{CICSTXN_ADMIN}}"
ADDRESS TSO "PE LWDADM CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{ADMINGROUP}})"

CALL rdef "GCICSTRN", "LWDSUB"
CALL addmem "GCICSTRN", "LWDSUB", "{{CICSTXN_SUBMIT}}"
ADDRESS TSO "PE LWDSUB CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{SUBMITUSER}})"

/* The scheduler's tick: its own transaction, for its userid only   */
CALL rdef "GCICSTRN", "LWDSCH"
CALL addmem "GCICSTRN", "LWDSCH", "{{CICSTXN_SCHED}}"
ADDRESS TSO "PE LWDSCH CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{SCHEDUSER}})"

/* The result step (POST /jobResults): its own transaction, for the */
/* deploy userids only. Repeat for every userid in DEPLUSER.          */
CALL rdef "GCICSTRN", "LWDJOB"
CALL addmem "GCICSTRN", "LWDJOB", "{{CICSTXN_RESULT}}"
ADDRESS TSO "PE LWDJOB CLASS(GCICSTRN) ACCESS(READ)" || ,
            " ID({{DEPLOYUSER}})"

/* Administrators (M5)                                                */
CALL rdef "FACILITY", "{{ADMINRES}}"
ADDRESS TSO "PE {{ADMINRES}} CLASS(FACILITY) ACCESS(READ)" || ,
            " ID({{ADMINGROUP}})"

/* One discrete profile per group in the RACFGRP allowlist (M7), with */
/* that group on its access list. Repeat for every group added later. */
grps = "{{DEMOACCESSGROUP}} {{DEMOOWNERGROUP}} {{DEMOAPPROVERGROUP}}"
DO i = 1 TO WORDS(grps)
   g = WORD(grps, i)
   CALL rdef "FACILITY", "{{GROUPPREFIX}}."g
   ADDRESS TSO "PE {{GROUPPREFIX}}."g "CLASS(FACILITY) ACCESS(READ)" || ,
               " ID("g")"
END

/* Only the submit task can submit as the deploy userid: JES checks  */
/* the submit userid and the CICS region userid, as CICS SPOOL writes */
/* to the internal reader from the region. Users can only start a    */
/* task as the submit userid, and it checks the job token before it  */
/* submits anything. It submits every job: the result step of job N  */
/* (POST /jobResults, under the deploy userid) starts it for job N+1, */
/* so the deploy userids may start it too.                           */
/* Repeat the first two for every userid in the DEPLUSER allowlist.  */
CALL rdef "SURROGAT", "{{DEPLOYUSER}}.SUBMIT"
ADDRESS TSO "PE {{DEPLOYUSER}}.SUBMIT CLASS(SURROGAT) ACCESS(READ)" || ,
            " ID({{SUBMITUSER}},{{CICSREGIONUSER}})"
CALL rdef "SURROGAT", "{{SUBMITUSER}}.DFHSTART"
ADDRESS TSO "PE {{SUBMITUSER}}.DFHSTART CLASS(SURROGAT) ACCESS(READ)" || ,
            " ID({{USERGROUP}},{{ADMINGROUP}},{{SCHEDUSER}}," || ,
            "{{DEPLOYUSER}})"

/* Acting as the scheduler's userid, for the members of             */
/* {{SCHEDGROUP}}: submit JCL with USER={{SCHEDUSER}}, such as LWDTICK */
/* (connect the workload scheduler's userid too), and su to it in    */
/* USS without its password, which it hasn't got: su -s {{SCHEDUSER}} */
CALL rdef "SURROGAT", "{{SCHEDUSER}}.SUBMIT"
ADDRESS TSO "PE {{SCHEDUSER}}.SUBMIT CLASS(SURROGAT) ACCESS(READ)" || ,
            " ID({{SCHEDGROUP}})"
CALL rdef "SURROGAT", "BPX.SRV.{{SCHEDUSER}}"
ADDRESS TSO "PE BPX.SRV.{{SCHEDUSER}} CLASS(SURROGAT) ACCESS(READ)" || ,
            " ID({{SCHEDGROUP}})"

/* DB2: the public plan, of LWDP. It holds only LWW's own packages,  */
/* so the CICS default userid can't run any LWD module.              */
plan = "{{DB2SSID}}.{{DB2PLAN_PUBLIC}}.EXECUTE"
CALL rdef "MDSNPN", plan
ADDRESS TSO "PE" plan "CLASS(MDSNPN) ACCESS(READ)" || ,
            " ID({{CICSDFLTUSER}},{{USERGROUP}},{{ADMINGROUP}})"

/* DB2: the plan. AUTHTYPE(USERID) makes RACF check each caller.      */
plan = "{{DB2SSID}}.{{DB2PLAN}}.EXECUTE"
CALL rdef "MDSNPN", plan
/* The submit, deploy and scheduler userids get it through          */
/* {{DB2GROUP}}.                                                      */
ADDRESS TSO "PE" plan "CLASS(MDSNPN) ACCESS(READ)" || ,
            " ID({{USERGROUP}},{{ADMINGROUP}},{{DB2GROUP}})"

/* DB2 in batch: LWDTICK runs LWDM940 and LWDM945 under the         */
/* scheduler's userid. The deploy userids reach DB2 only through     */
/* CICS since iteration 4, so not in batch: no static SQL of the     */
/* plan outside LWD's programs. Before iteration 4 the result step   */
/* (LWDM915) ran in batch: the DELETE takes that away; run this job  */
/* again once no job of before iteration 4 is running any more.      */
ADDRESS TSO "PE {{DB2SSID}}.BATCH CLASS(DSNR) ACCESS(READ)" || ,
            " ID({{SCHEDUSER}})"
ADDRESS TSO "PE {{DB2SSID}}.BATCH CLASS(DSNR) DELETE" || ,
            " ID({{DEPLOYUSER}})"

/* Entra: the result step signs in with an access token from Entra, */
/* asked for with a client assertion that JWTSignerUtil signs with   */
/* the private key of the deploy userid's own certificate, on its own */
/* key ring; certificate label and key ring are both the userid      */
/* (docs/12-iteration-8.md). Each is made only when it isn't there,  */
/* so a certificate made by hand stays. The private key is kept in   */
/* the RACF database; add PKDS to GENCERT to keep it in ICSF. Valid  */
/* for 2 years: renew it in time (docs/12). Afterwards upload the    */
/* certificate, not the key, to the Entra application of the userid  */
/* (DEPLOYAPPID in envs/<env>.yaml):                                  */
/*   RACDCERT ID(du) EXPORT(LABEL('du')) DSN(...) FORMAT(CERTB64)    */
/* READ on IRR.DIGTCERT.LISTRING lets a userid read its own key      */
/* rings, private keys included; a profile in RDATALIB that covers   */
/* the ring takes precedence when that class is active.              */
/* Repeat for every userid in DEPLUSER.                               */
du = "{{DEPLOYUSER}}"
IF quiet("RACDCERT ID("du") LISTRING("du")") <> 0 THEN
   ADDRESS TSO "RACDCERT ID("du") ADDRING("du")"
IF quiet("RACDCERT ID("du") LIST(LABEL('"du"'))") <> 0 THEN DO
   today = DATE('S')
   md = SUBSTR(today, 5, 4)
   IF md = '0229' THEN md = '0228'
   until = LEFT(today, 4) + 2'-'LEFT(md, 2)'-'RIGHT(md, 2)
   ADDRESS TSO "RACDCERT ID("du") GENCERT" || ,
               " SUBJECTSDN(CN('"du"') OU('LWD'))" || ,
               " SIZE(2048) RSA NOTAFTER(DATE("until"))" || ,
               " WITHLABEL('"du"')"
END
connected = 0
IF quiet("RACDCERT ID("du") LISTRING("du")") = 0 THEN
   DO i = 1 TO out.0
      IF POS('ID('du')', out.i) > 0 THEN connected = 1
   END
IF \connected THEN
   ADDRESS TSO "RACDCERT ID("du") CONNECT(ID("du") LABEL('"du"')" || ,
               " RING("du") USAGE(PERSONAL) DEFAULT)"
CALL rdef "FACILITY", "IRR.DIGTCERT.LISTRING"
ADDRESS TSO "PE IRR.DIGTCERT.LISTRING CLASS(FACILITY) ACCESS(READ)" || ,
            " ID("du")"

/* The output collector (S3) reads the output of the deployment jobs */
/* with SDSF: all their names start with {{JOBPREFIX}}, whatever deploy */
/* userid they ran under. Needs GENERIC(JESSPOOL).                    */
spool = "{{JESNODE}}.*.{{JOBPREFIX}}*.**"
CALL rdef "JESSPOOL", spool
ADDRESS TSO "PE" spool "CLASS(JESSPOOL) ACCESS(READ)" || ,
            " ID({{SCHEDUSER}})"

ADDRESS TSO "SETR RACLIST(MDSNPN) REFRESH"
ADDRESS TSO "SETR RACLIST(DSNR) REFRESH"
ADDRESS TSO "SETR RACLIST(FACILITY) REFRESH"
ADDRESS TSO "SETR RACLIST(TCICSTRN) REFRESH"
/* TLS of the result step: System SSL keeps the session's clear keys */
/* in the system PKCS #11 token of ICSF. Only a PERMIT: the profile   */
/* belongs to the site and must exist already (PERMIT gives a message */
/* if not); a new UACC(NONE) profile here could block others.         */
/* Repeat for every userid in DEPLUSER.                               */
ADDRESS TSO "PE CLEARKEY.SYSTOK-SESSION-ONLY CLASS(CRYPTOZ)" || ,
            " ACCESS(READ) ID({{DEPLOYUSER}})"

/* Email addresses (S4 step 5, JCL/LWDMAIL): the scheduler's userid */
/* reads WAEMAIL of every LWD user with IRRXUTIL (R_admin). Three    */
/* things are needed, as found on t01 (docs/11-iteration-7.md):      */
/* 1. READ on IRR.RADMIN.LISTUSER: R_admin refuses a problem-state   */
/*    caller without it (IRRXUTIL RC 12 12 8 8 24), also when the    */
/*    profile doesn't exist, so defining it takes nothing away.      */
/* 2. READ on IRR.LISTUSER: authority to list the base segment of    */
/*    other users. Without any authority over a user, R_admin        */
/*    refuses it with the same 12 12 8 8 24; field-level access      */
/*    alone isn't enough. Not for users with SPECIAL, AUDITOR or     */
/*    OPERATIONS: LWD keeps their address as it is (LWDR961 X).      */
/*    Before the first run: RLIST FACILITY IRR.LISTUSER GEN. A       */
/*    generic profile that covers it may grant it to others today;   */
/*    a discrete UACC(NONE) profile would take that away from them.  */
/* 3. READ on FIELD USER.WORKATTR.WAEMAIL: field-level access to    */
/*    the address in the WORKATTR segment, which IRR.LISTUSER        */
/*    doesn't give. A FIELD profile name holds the segment: a        */
/*    profile USER.WAEMAIL protects nothing (found on t01). The      */
/*    FIELD class must be active and RACLISTed                       */
/*    (SETR CLASSACT(FIELD) RACLIST(FIELD)), which this job doesn't  */
/*    do; otherwise R_admin leaves the segment out without an error. */
CALL rdef "FACILITY", "IRR.RADMIN.LISTUSER"
ADDRESS TSO "PE IRR.RADMIN.LISTUSER CLASS(FACILITY)" || ,
            " ACCESS(READ) ID({{SCHEDUSER}})"
CALL rdef "FACILITY", "IRR.LISTUSER"
ADDRESS TSO "PE IRR.LISTUSER CLASS(FACILITY)" || ,
            " ACCESS(READ) ID({{SCHEDUSER}})"
CALL rdef "FIELD", "USER.WORKATTR.WAEMAIL"
ADDRESS TSO "PE USER.WORKATTR.WAEMAIL CLASS(FIELD) ACCESS(READ)" || ,
            " ID({{SCHEDUSER}})"

ADDRESS TSO "SETR RACLIST(SURROGAT) REFRESH"
/* Give a message when DIGTCERT and DIGTRING are not RACLISTed      */
ADDRESS TSO "SETR RACLIST(DIGTCERT) REFRESH"
ADDRESS TSO "SETR RACLIST(DIGTRING) REFRESH"
ADDRESS TSO "SETR RACLIST(CRYPTOZ) REFRESH"
ADDRESS TSO "SETR RACLIST(FACILITY) REFRESH"
ADDRESS TSO "SETR RACLIST(FIELD) REFRESH"
ADDRESS TSO "SETR GENERIC(JESSPOOL) REFRESH"
/* Gives a message when JESSPOOL is not RACLISTed                    */
ADDRESS TSO "SETR RACLIST(JESSPOOL) REFRESH"

EXIT 0

/* ----------------------------------------------------------------- */
/* Create only what doesn't exist yet, so running this job again     */
/* gives no messages about what is there already. Each looks first   */
/* with a listing command, its output trapped: RC 0 means found.     */
/* ----------------------------------------------------------------- */

/* rdef: RDEFINE class profile UACC(NONE), unless it exists. A       */
/* profile with * or % is looked up as a generic one.                */
rdef: PROCEDURE
  PARSE ARG class, profile
  IF rlisted(class, profile) THEN RETURN
  ADDRESS TSO "RDEF" class profile "UACC(NONE)"
  RETURN

/* addmem: RALTER ADDMEM(member), unless the profile has it          */
addmem: PROCEDURE
  PARSE ARG class, profile, member
  IF rlisted(class, profile) THEN
    DO i = 1 TO out.0
      IF WORDPOS(member, out.i) > 0 THEN RETURN
    END
  ADDRESS TSO "RALT" class profile "ADDMEM("member")"
  RETURN

/* rlisted: 1 if RLIST shows this very profile, its output in out.   */
/* RC 0 alone isn't enough: when the name has no profile of its own, */
/* RLIST shows the generic profile that covers it (such as *.**,     */
/* marked (G)) with RC 0. So compare the name under CLASS NAME.      */
rlisted:
  PARSE ARG rclass, rprof
  rprof = TRANSLATE(rprof)
  rgen = ''
  IF VERIFY(rprof, '*%', 'M') > 0 THEN rgen = 'GENERIC'
  IF quiet("RLIST" rclass rprof rgen) <> 0 THEN RETURN 0
  DO r = 1 TO out.0 - 1
    IF LEFT(STRIP(out.r), 5) = '-----' THEN DO
      r = r + 1
      RETURN WORD(out.r, 2) == rprof
    END
  END
  RETURN 0

/* addgroup: ADDGROUP, unless the group exists                       */
addgroup: PROCEDURE
  PARSE ARG group
  IF quiet("LISTGRP" group) = 0 THEN RETURN
  ADDRESS TSO "ADDGROUP" group
  RETURN

/* adduser: ADDUSER with its options, unless the userid exists       */
adduser: PROCEDURE
  PARSE ARG user, options
  IF quiet("LISTUSER" user "NORACF") = 0 THEN RETURN
  ADDRESS TSO "ADDUSER" user options
  RETURN

/* connect: CONNECT, unless the userid is connected to the group     */
/* (LISTUSER shows GROUP=group for each connect group)               */
connect: PROCEDURE
  PARSE ARG user, group
  IF quiet("LISTUSER" user) = 0 THEN
    DO i = 1 TO out.0
      IF POS(' GROUP='group' ', ' 'out.i' ') > 0 THEN RETURN
    END
  ADDRESS TSO "CONNECT" user "GROUP("group")"
  RETURN

/* quiet: a listing command, its output trapped in out. for the      */
/* caller; returns its RC                                            */
quiet:
  PARSE ARG command
  x = OUTTRAP('out.')
  ADDRESS TSO command
  qrc = rc
  x = OUTTRAP('OFF')
  RETURN qrc
$$
