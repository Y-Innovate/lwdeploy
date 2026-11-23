# Iteration 4: the result step over REST

Until now the result step ran LWDM915 in batch: static SQL under the deploy
userid, which also wrote job N+1 to the internal reader. That had two
consequences:
- The deploy userids needed DB2 in batch (`DSNR` `BATCH` and the plan), so they
  could run LWD's static SQL outside LWD's programs.
- A job had to run on an LPAR with LWD's DB2. A job sent to another node with
  `/*XEQ` couldn't record its result.

This iteration replaces that step with one that calls LWD's REST API:
- **Result step:** REXX `LWDR916` signs in as the deploy userid with a RACF
  PassTicket, then sends the outcome to `POST /jobResults` (S2).
- **`POST /jobResults` (`LWDM916`):** takes over LWDM915's decisions. For the
  next job it creates a run and starts the CICS submit task, as for the first
  job. CICS now submits every job (M9).
- **Execution node:** an optional JES2 node per environment (`EXECNODE`).
  LWDM920 adds `/*XEQ` for it (M12).
- **Output collector:** finds a job by its name only, because a job that ran
  on another node has a different job ID locally.
- **Deploy userids lose DB2 in batch.** They still reach DB2 through CICS, as
  every user does.

Nothing here has been compiled or run yet.

## Why a PassTicket

The result step needs a token for `POST /jobResults`, and `POST /token` wants
a userid and a password. Nobody knows a password or passphrase for the deploy
userid, and one stored for the job would be readable by whoever can read the
JCL or the library.

A PassTicket solves this:
- It is a one-time password of 8 characters, which RACF generates for the
  userid the job runs under and checks like a password. LWW checks it with
  `VERIFY TOKEN` `TOKENTYPE(BASICAUTH)`, which accepts a PassTicket as the
  password, and returns a JWT.
- RACF only lets a userid generate one for itself, and only with UPDATE on
  `IRRPTAUTH.<applid>.<userid>`. The key stays in RACF.
- It works once (unless the profile allows replay) and only for a short
  time: about 10 minutes for a legacy PassTicket, the profile's `TIMEOUT` for
  an enhanced one (60 seconds on t01). With the step's `IF` tests and the run
  that must be `S`, a result can't be sent twice anyway.

## What is built

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| POST `/jobResults` | `LWDC916` | `LWDM916` | S2 |

The path has its own tag, `job`, and its own transaction, `LWDJ`, which only
the deploy userids may run. The body holds `runID`, `jobName`, `jesJobID` and
`jobResult` (O, H or A). The response holds the run's and the deployment's
status and `nextRunID`, the run handed to the submit task.

| Return, reason | HTTP | When |
|---|---|---|
| `00 00` | 200 | Recorded |
| `00 01` | 200 | A late result: the scheduler had set the run stuck (T); recorded on the run only |
| `04 01` | 404 | Run not found |
| `08 01` | 400 | `jobResult` is not O, H or A |
| `08 50` | 403 | Not the deploy userid of the deployment, or not the job name of the run |
| `08 53` | 409 | The run was recorded already, or is not submitted |

New:

| Program | What it is |
|---|---|
| `REXX/LWDR916` | The result step: PassTicket, `POST /token`, `POST /jobResults`, with the z/OS client web enablement toolkit (HWTHTTP). `%LWDR916 TEST` only signs in |
| `LWDA916` | Assembler without LE, called from LWDR916 with `ADDRESS LINKPGM`: a PassTicket from R_ticketserv (IRRSPK00, linked from `SYS1.CSSLIB`). A COBOL routine (LWDU916) abended U4093 there, as LE could not start, with `LINKPGM` and with `ATTCHPGM` alike |
| `LWDM916`, `LWDC916` | `POST /jobResults` |
| `JCL/LWDPTKT` | Tries the sign-in on its own, before any deployment |
| `DDL/ALTITR4` | `ENVIRONMENTS.EXECNODE` for an existing table |

Changed:

| Program or file | Change |
|---|---|
| `LWDM920` | Builds the new result step and `/*XEQ`. Reads the new settings instead of the DB2 ones |
| `REXX/LWDR941` | Matches a job by name only; the job ID only decides between two of the same name |
| `LWDM915` | Unchanged, but no longer put into new jobs. It stays for jobs submitted before this iteration |
| `LWDC910` | Header only: it now submits every job |
| `DDL/SETTINGS` | Without `DB2SSID`, `DB2HLQ`, `DB2SSHLQ` and `DB2PLAN`; with `EXECLIB`, `LWDURL`, `LWDPORT`, `LWDPATH`, `LWWAPPL` and `LWDRING` |
| `DDL/AA000009`, `TBLWD006` | `EXECNODE`, after the audit columns, where `ALTER TABLE ADD` puts it |
| `JCL/RACF` | See below |
| `JCL/CICSCSD` | Transaction and DB2ENTRY `LWDJ` |
| `ZMAKE/BUILD.zmake` | `SYS1.CSSLIB` in the link-edit SYSLIB |
| `python/genddl.py` | Columns added later (`tail`), and the `$INFO.txt` lines that were added by hand |

## The result step

LWDM920 puts this step into every job, under the same `IF` tests as before,
as `LWDRSA`, `LWDRSO` and `LWDRSH`:

```
//LWDRSO   EXEC PGM=IKJEFT1B,PARM='%LWDR916 000001234 O'
//STEPLIB  DD DISP=SHR,DSN=YINCIC.CPSM.T01.LWD.LOAD
//SYSEXEC  DD DISP=SHR,DSN=YINCIC.CPSM.T01.LWD.EXEC
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DUMMY
//LWDCONF  DD *
URL=https://<host>
PORT=<port>
PATH=/lwdeploy/API/v1
APPLID=CICSLWW
KEYRING=*AUTH*/*
```

The step then works like this:
1. It takes the userid with `USERID()`, the job name from the TIOT and the JES
   job ID from the SSIB.
2. `LWDA916` makes a PassTicket for that userid and `APPLID`.
3. `POST /token` with the userid and the PassTicket. When LWW refuses it
   (401, or 500 with CICS reporting a wrong password) it tries again with a
   new ticket after 2 seconds, and once more after 5, sleeping through z/OS
   UNIX. On t01 the second job of a deployment was refused right after the
   first one's result step had signed in: with replay protection RACF
   refuses a ticket it has seen, and a new ticket for the same userid and
   applid can come out the same when it is made shortly after the last.
4. `POST /jobResults` with the bearer token.

| RC | Meaning |
|---|---|
| 0 | Recorded |
| 4 | Late result, or recorded already |
| 8 | Not recorded: see `SYSTSPRT`. The run stays `S` until the scheduler marks it stuck after `JOBMINS`; then a deployer retries (D4) |

`LWDR916` never shows the PassTicket or the token. With `https` it uses the
toolkit's own TLS (`HWTH_OPT_USE_SSL`) with the key ring `KEYRING`. The
virtual key ring `*AUTH*/*` holds every CERTAUTH certificate, so no key ring
per deploy userid is needed, as long as the CA of LWW's certificate is in
RACF as CERTAUTH. With `http://` in `LWDURL` the toolkit does no TLS; AT-TLS
can add it for the port, for example when a site's policy requires that.

## How a deployment goes now

| Event | What happens | Program |
|---|---|---|
| Start (D1, AP2, S4, D4) | Run of the first job, submit task | As before |
| Result O, another job waits | Job D, run of the next job, submit task after the commit | `LWDM916`, wrapper `LWDC916` |
| Result O, last job | Deployment S, inventory, environment free; its oldest due Q deployment starts at once | `LWDM916` (`LWDSTRP` `R730`) |
| Result H or A | Run E, job and deployment F, environment H | `LWDM916` (`LWDDEPP` `R660`) |

So job N+1 is submitted by the submit userid under `USER=` the deploy userid,
as job 1 always was, and no deployment job writes to the internal reader any
more. A deployment that ends now also starts the next queued one right away,
instead of at the next tick.

## Execution node

`ENVIRONMENTS.EXECNODE` holds a JES2 node name. When set, LWDM920 writes
`/*XEQ <node>` right after the JOB statement, and JES2 sends the job there over
NJE. Until the admin API exists, set it in DB2 (`DDL/ALTITR4` shows how).

For that to work:
- The node must trust this node's userids (NJE), so the job runs under the
  deploy userid there.
- The deploy userid needs on that system what the job itself needs, an OMVS
  segment, READ on CRYPTOZ `CLEARKEY.SYSTOK-SESSION-ONLY`, plus READ
  on copies of the load and EXEC libraries under the same names. It also
  needs a PTKTDATA profile and IRRPTAUTH permission in the RACF database there,
  with the same key as here when the RACF databases differ.
- The system must reach LWW over TCP/IP, with the CA in RACF there.
- The output comes back to this node, where the collector finds it by job name.
  The run keeps the JES job ID that the result step sent, from the node where
  it ran.

`SYSAFF`, to pick a system within a JES2 MAS, is not built.

## Setting it up on t01

1. **`envs/t01.yaml`:** check `LWWAPPLID` and `CICSTXN_RESULT` (below).
2. **DDL:** `python python/deploy.py DEPLOY_DDL`, then run with `RUNDDL`:
   - `ALTITR4`: the new column
   - `SETTINGS`: the new settings
3. **Build and deploy:** `. ./setenv`, `build`, then `python python/deploy.py`.
   - New: `LWDM916`, `LWDC916`, `LWDA916`, `REXX/LWDR916`, `JCL/LWDPTKT`.
   - Changed: `LWDM920` (`LWDM915` is linked with it), `LWDR941`.
4. **CICS:** submit `CICSCSD` for `LWDJ`, install it and the new programs
   `LWDC916` and `LWDM916`, and NEWCOPY `LWDM920`.
5. **RACF:** submit `RACF` again. New:
   - `GCICSTRN LWDJOB` with `LWDJ`, and `DFHDB2.AUTHTYPE.LWDJ`, for the deploy
     userid
   - `SURROGAT LWDSUBM.DFHSTART` for the deploy userid as well, as its
     results start the submit task
   - PTKTDATA `CICSLWW` and `IRRPTAUTH.CICSLWW.LWDDEPL` with UPDATE for the
     deploy userid
   - An OMVS segment for the deploy userid (AUTOUID, needs BPX.NEXT.USER;
     only when it has no UID yet). Without one the result step fails on
     `HWTHINIT` with RC 3845: the toolkit opens its sockets through z/OS
     UNIX
   - READ on CRYPTOZ `CLEARKEY.SYSTOK-SESSION-ONLY` for the deploy userid:
     System SSL keeps the TLS session's clear keys in ICSF's system PKCS #11
     token. Only a PERMIT, as the profile belongs to the site and must exist
   - The deploy userid's `DSNR` `BATCH` permission is deleted. Jobs submitted
     before this iteration still run LWDM915, which needs it: submit `RACF`
     only when none of them is running

   Not in the job: READ on `YINCIC.CPSM.T01.LWD.EXEC` for the deploy userid.
6. **A passphrase for the deploy userid**, by hand, never in a job or in git.
   The RACF job creates it protected (NOPASSWORD), and RACF refuses a
   PassTicket for a protected userid: generating works, verifying fails with
   RACF RC 8 and no ICH408I. Give it a long passphrase that nobody keeps, so
   it is no longer protected, and keep the phrase from expiring:
   ```
   ALU LWDDEPL PHRASE('<long, random>') NOEXPIRED
   PASSWORD USER(LWDDEPL) NOINTERVAL
   ```
   It can now be revoked by wrong sign-on attempts, which stops every result
   step under it: `ALU LWDDEPL RESUME`. Repeat for every userid in DEPLUSER.
7. **The PassTicket key**, not in git. On t01 the profile of LWW's region
   already had an enhanced PassTicket key (`SSIGNON` segment: key label in
   ICSF, `TIMEOUT(60)`, `REPLAY(NO)`). It needs `TYPE(UPPER)`:
   ```
   RALT PTKTDATA <applid> SSIGNON(EPTKTDATA(TYPE(UPPER)))
   SETR RACLIST(PTKTDATA) REFRESH
   ```
   With `TYPE(MIXED)` the ticket has lowercase letters, and every verify fails
   with RACF RC 8 and no ICH408I: a password of 8 characters or fewer is
   uppercased on its way to RACF, here without `SETROPTS
   PASSWORD(MIXEDCASE)`. The replay setting of an enhanced PassTicket is
   `REPLAY` in that segment; `APPLDATA('NO REPLAY PROTECTION')` only applies
   to a legacy one.
   Where the profile has no key yet: a legacy key with
   `SSIGNON(KEYMASKED(<16 hex digits>))` or `KEYENCRYPTED` with ICSF, or an
   enhanced key in ICSF with `TYPE(UPPER)`. PTKTDATA must be active (`SETR
   CLASSACT(PTKTDATA)`). Older levels also check FACILITY `IRR.RTICKETSERV`
   for R_ticketserv: check whether yours does.
8. **LWW:** copy both specs from `openapi/` to `remoteOASDir`, then
   `python python/processYAML.py` and `python python/uploadLWW.py` (the
   placeholder `jobResults` runs under `LWDJ`).
9. **Try the sign-in:** give yourself UPDATE on
   `IRRPTAUTH.CICSLWW.<your userid>`, submit `LWDPTKT`, and read `SYSTSPRT`.
   RC 0 means the PassTicket, TLS and `POST /token` work. Take the permission
   away again.

## Trying it

`python/testIteration4.py` signs in as the deployer, then:
1. deploys `V1.0.0` to DEV and waits for S. Both runs must be E with result O
   and have a JES job ID, which only LWDR916 sends. Job 2 was submitted by
   the submit task
2. sends `POST /jobResults` as the deployer: refused (401 or 403), as only the
   deploy userids may run `LWDJ`
3. deploys `V1.0.1-BAD`: F, with job 2 E and result H
4. cancels it, so DEV is free

`testIteration3.py` still applies: it checks the steps `LWDRSO`, `LWDRSA` and
`LWDRSH` by name, and they keep those names.

## Values to check in `envs/t01.yaml`

| Key | Value now | What it is |
|---|---|---|
| `LWWAPPLID` | `CICSLWW` | Applid of LWW's CICS region (generic applid with XRF): the PTKTDATA profile; placeholder |
| `CICSTXN_RESULT` | `LWDJ` | Transaction of `POST /jobResults`; check that it is free in the region |
| `LWDURL`, `LWDPORT`, `LWDPATH` | `https://<host>`, `<port>`, `/lwdeploy/API/v1` | Where the result step finds LWW, as the deployment jobs' system sees it |
| `LWDKEYRING` | `*AUTH*/*` | Key ring with the CA of LWW's certificate |

## To check on the first run

- **R_ticketserv:** the parameter list of `LWDA916` follows a working example,
  not the manual: 14 parameters, with an ALET before each return and reason
  code and before the function code; function code 3, ticket options 1, and
  each area a halfword length followed by the value. Without the ALET before
  the function code RACF abended 0E0-29 (ICH409I). If `LWDPTKT` shows SAF
  and RACF codes other than 0, check the order against *z/OS Security
  Server RACF Callable Services*, R_ticketserv, for this level.
- **LWW and VERIFY TOKEN:** settled: `TOKENTYPE(BASICAUTH)` accepts the
  PassTicket, verified against the region's applid, once the ticket is
  `TYPE(UPPER)`.
- **HWTHTTP from REXX:** `hwtcalls`, `hwtconst` (checked: not `hwthconst`), the option names, the
  response body in `HWTH_OPT_RESPONSEBODY_USERDATA`, and TLS 1.2. `SYSTSPRT`
  shows the toolkit's reason when a call fails.
- **The JES job ID:** from the SSIB; it should match the job's output.
- **The submit task under the deploy userid's request:** the wrapper starts it
  with `USERID(LWDSUBM)`, which needs the DFHSTART surrogate (step 5).
- **Timing:** a result step now waits for an HTTP round trip and a sign-in
  instead of a DB2 call: a few seconds per job.

## Not built yet

- **Mail (S5)**, and the email refresh of S4.
- **The admin API**, template editing and variables. `EXECNODE` is set in DB2
  until then.
- **`GET /deployments`**, the list: [iteration 5](09-iteration-5.md).
- **`SYSAFF`** within a JES2 MAS.
- **Removing LWDM915** and `MODE-BATCH` of LWDM920, once no job of before
  this iteration runs anywhere.
- **Marking a run stuck by hand (admin):** when a result step fails, for
  example on a setting or a permission, its run stays `S` and the deployment
  `U` until the scheduler marks it stuck after `JOBMINS`; until then nobody
  can cancel or retry it (D3 refuses while a job is submitted). An admin
  action should set such a run F with result T at once, as LWDM930 does, for
  a job that has ended in JES. Until it exists: lower `JOBMINS` for a moment
  and run `LWDTICK`. Use case A4, with the admin API.
