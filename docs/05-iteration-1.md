# Iteration 1: from version to deployed

The first COBOL slice. It proves the riskiest parts end to end:
- the FACILITY group checks (M7)
- frozen JCL with variables
- submission under the deploy userid
- the result step submitting the next job (M9)
- the inventory
- base64 output

Nothing here has been compiled or run yet.

## What is built

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| POST `/token` | `LWWADPLI` (LWW's own) | | U1, O4 (CI) |
| GET `/me` | `LWDC302` | `LWDM302` | U1 |
| GET `/applications` | `LWDC204` | `LWDM204` | M1 |
| GET `/environments` | `LWDC206` | `LWDM206` | M1, M2 |
| GET `/versions` | `LWDC205` | `LWDM205` | M2, D1 |
| POST `/versions` | `LWDC405` | `LWDM405` | O4 |
| POST `/deployments` | `LWDC411` | `LWDM411` | D1, S1 |
| GET `/deployments/{deplID}` | `LWDC311` | `LWDM311` | M3, D2 |
| POST `/cancellations/{deplID}` | `LWDC511` | `LWDM511` | D3 |
| GET `/deploymentJobs` | `LWDC212` | `LWDM212` | M3, D2 |
| GET `/deploymentJcl/{deplID}` | `LWDC313` | `LWDM313` | M3 |

All are `user` paths, transaction `LWDU`. The numbers are:
- first digit: 2 list, 3 get, 4 create, 5 action, 9 support
- last two digits: the table, as in [03-data-model.md](03-data-model.md)

Support programs:

| Program | Purpose |
|---|---|
| `LWDC910` | Submits a run through CICS SPOOL; initial program of transaction `LWDS`, started by `LWDC411` under the submit userid |
| `LWDM910` | Claims a run with its token (C), or sets it failed (F) |
| `LWDM920` | Builds the JCL records of a run: JOB statement, frozen JCL, result step. No CICS commands, so the result step can use it too |
| `LWDM915` | Batch: the result step. Records the outcome and submits the next job, or ends the deployment. Linked with `LWDM920` and `DSNELI` |
| `LWDA990` | Userid; in batch also the job name and JES job ID (from the JSAB). A copy of `CTFA990` with those two added |
| `LWDA991` | Random bytes and SHA-256 with CPACF, a copy of `CTFA991` |
| `LWDA992` | `EXEC CICS QUERY SECURITY` for the DB2 modules, which have no CICS translator: the group and administrator checks |
| `LWDU981` | Base64. Plain COBOL, without CICS or DB2, built with `OPTFILE/COBOL.opt`: a new `LWDU` class in `BUILD.zmake` |

Copybooks:

| Copybook | What it holds |
|---|---|
| `LWDCTXW`, `LWDCTXP` | User context for every module: userid, settings, FACILITY checks, roles in an application, group cache, SQL error handling |
| `LWDDEPW`, `LWDDEPP` | New runs (sequence key, job name, token), history events, and a run that failed. Shared by `LWDM411`, `LWDM511`, `LWDM910` and `LWDM915` |
| `LWDSECW`, `LWDSECP` | Job token and its hash |
| `LWDSUBW`, `LWDSUBP` | Starting the submit task from a wrapper |
| `LLWDMnnn` | IO area of each module |
| `TBLWDnnn` | Layout of each table, to be compared with a real DCLGEN |

## Generated, not written by hand

| What | By | From |
|---|---|---|
| `DDL/AA000004`-`AA000023`, `COPY/TBLWDnnn.cpy`, table names in `envs/t01.yaml` | `python/genddl.py` | The table definitions in the script |
| `DDL/SEEDDATA.sql` | `python/genseed.py` | The demo application in the script |
| `openapi/lwd_1.0.0.yaml`, the endpoint tables of 04 | `python/genoas.py` | The operation list in the script |
| `COPY/LLWDMnnn.cpy`, `openapi/lwd_2_1.0.0.yaml`, `COBOL/LWDCnnn.cbl` (wrappers), `LKED/*.lked` | `python/genlww.py` | `OPS` in the script and `python/wrapper.cbl.tpl` |

To add an operation in a later iteration:
1. Add it to `OPS` in `genlww.py`.
2. Run `genoas.py`, then `genlww.py`.
3. Write the module by hand.

`genlww.py` checks two things against `lwd_1.0.0.yaml`:
- Every field of a response is in its schema, and the other way round.
- The parameters match.

So the copybooks and the contract can't drift apart. `genoas.py` adds an `x-LWWProcessingSteps` reference only for operations in `OPS`, as CTF did, so LWW never meets a dangling reference.

## How a deployment runs

```
POST /deployments (LWDC411 -> LWDM411)
  checks, deployment W or Q, JCL frozen per template
  Q and due: takes the environment, U, run of job 1 with a token
  commit; START LWDS under the submit userid
LWDC910 -> LWDM910 C: token checked, run S, commit
        -> LWDM920 C: JOB with USER=deploy userid, frozen JCL, result step
        -> SPOOLOPEN/SPOOLWRITE/SPOOLCLOSE to INTRDR
job 1 runs under the deploy userid; its result step runs LWDM915:
  O: job D; job 2 waits: new run, LWDM920 B (no USER=), written to DD INTRDR
     no job waits: deployment S, inventory, environment free
  H, A: run E, job F, deployment F, environment H (still held)
```

Three decisions come out of this:

- **M9, next job:** the result step submits it, under the same deploy userid, so no surrogate is needed and nothing polls.
- **The JOB statement isn't frozen.** It is built at each submission, because the job name contains RUNID and a retry is a new run. The approver sees the steps and the deploy userid; the JOB statement and result step are always the same.
- **RUNID comes from a sequence (`SQLWD014`), not an identity column,** so the job name is known before the insert. The job name is `JOBPRFX` followed by RUNID in base 36, 6 characters.

The result step checks two things through `LWDA990`:
- its own job name matches the run's
- its userid is the deployment's deploy userid

So it can't be used to submit another run's JCL.

## Not built yet

Approval, scheduling, retry and continue, and stuck runs came in
[iteration 2](06-iteration-2.md). As iteration 1 left them:

- **Approval.** A deployment to an environment with approval stays W; it can only be cancelled. AP1 and AP2 come in iteration 2.
- **Scheduling.** A Q deployment for later, or one that finds its environment busy, stays Q: the scheduler (S4) starts it later. Until then, cancel it.
- **Retry and continue (D4)** after a failure, and stuck jobs: a run without a result stays S. Cancel the deployment.
- **Job output (S3).** The JOB statement has no OUTPUT statement for the CICS writer yet, so the output stays in JES only. `JOBRC`, `ABENDCODE` and the step return codes come with S3, from the output.
- **Mail (S5)**, the email refresh (S4), the admin API, template editing and variables: `SEEDDATA.sql` holds what is needed.
- **Late results:** a result that arrives after the deployment left U (cancelled) only updates its run.

## DB2 plans and collections

| Plan | Collection | Used by | Packages |
|---|---|---|---|
| `LWDT01` | `LWDT01` | `LWDU`, `LWDA`, `LWDS`, and the result step of every deployment job | All `LWDM` modules |
| `LWDT01P` | none | `LWDP`, since iteration 5 | Only LWW's own (`LWWMIOC`, `LWWMFIST`), to serve the web UI's files |

There are no public paths, so one plan is enough for LWD's modules. The
public plan exists so the CICS default userid, which runs `LWDP` before
sign-in, never gets EXECUTE on a plan with LWD's modules. `DEPLOY.zmake` binds every `LWDM` member into the collection and only copies the rest.

## Setting it up on t01

Check the values at the end of `envs/t01.yaml` first; see below.

1. Create, if they don't exist:
   - group `USERGROUP`, for everyone who uses LWD
   - the demo groups `DEMOACCESSGROUP`, `DEMOOWNERGROUP` and `DEMOAPPROVERGROUP`

   The `RACF` job (step 7) creates the DB2 group `DB2GROUP` and the
   userids `SUBMITUSER` and `DEPLOYUSER`, and connects both userids to
   `DB2GROUP`. After that, give:
   - `DEPLOYUSER` READ on `LOADLIB`
   - `SUBMITUSER` access to the CICS region, if the `APPL` class is active
2. `python python/deploy.py DEPLOY_DDL`. This renders the DDL and JCL only.
3. With `RUNDDL`, run `AA000001` to `AA000023`, then `SETTINGS` and `SEEDDATA`.
4. `. ./setenv`, then `build`.
5. `python python/deploy.py`. This copies the modules and binds the packages.
6. Submit `BINDPLAN`.
7. Submit `CICSCSD` and `RACF`, and install group `GLWDT01`. `RACF` defines:
   - the DB2 group, and the submit and deploy userids in it
   - the transactions
   - the administrator and group FACILITY profiles
   - the surrogate profiles
   - the plan

   DB2 is RACF controlled, so there are no `GRANT`s.
8. Copy `python/runtimeTargets.example.yaml` to `python/runtimeTargets.yaml`
   (gitignored) and fill in the host, userid and `remoteOASDir`.
9. Copy both specs in `openapi/` to `remoteOASDir` on z/OS. Then run
   `python python/processYAML.py`, which registers `lwd_1.0.0.yaml` with path
   prefix `/lwdeploy/API/v1`.
10. `python python/uploadLWW.py` creates the folder `/lwdeploy` (ID `LD000000`) and
    uploads `LWWAdmin/`. The placeholder files in `LWWAdmin/API/v1` set the
    transaction per path:
    - `LWDU` for the user paths
    - `LWDA` for `/admin`
    - LWW's own `LWBL` for `/token`

    `index.html` and the sign-in pages also run under `LWBL`, because LWD has
    no anonymous transaction. (Since iteration 5 `index.html`, `assets/` and
    the login folder run under LWD's public `LWDP`; `LWBL` is for LWW's own
    sign-in pages only.) `index.html` is a placeholder until the web UI
    exists. Use `--dry-run` first to see what it would change.

To try it, a userid needs to be:
- in `USERGROUP`
- in `DEMOACCESSGROUP`, to deploy
- in `DEMOOWNERGROUP`, to register versions

Run `SETROPTS RACLIST(FACILITY) REFRESH` after connecting it. The cached groups refresh after `GRPMINS` minutes (15); every action checks live.

## Trying it

With the demo application `DEMO` from `SEEDDATA.sql`:

1. `GET /me`, `GET /applications`: `DEMO`, with `isMember` and `isOwner` Y.
2. `GET /environments?appID=` and `GET /versions?appID=`.
3. `POST /versions` with a new name, as CI would.
4. `POST /deployments` of `V1.0.0` to DEV; poll `GET /deployments/{id}` until `S`. In SDSF:
   - jobs `LT000001` and `LT000002`, under `DEPLOYUSER`
   - each with the steps of its template, then `LWDRSO` running `LWDM915`
5. `GET /deploymentJobs?deplID=` and `GET /deploymentJcl/{id}?jobNo=1`, then decode the base64.
6. `POST /deployments` of the new version to TST: 409, `08 54`, the gate.
7. `POST /deployments` of `V1.0.0` to TST: it passes DEV, so `S`.
8. `POST /deployments` of `V1.0.1-BAD` to DEV:
   - job 2 sets RC 8, above its highest RC 4, so the deployment is `F`
   - DEV is held and `H`
   - `POST /cancellations/{id}` frees it
9. `POST /deployments` to PRD: `W`, waiting for approval. Cancel it.

`python python/testIteration1.py` runs these steps and checks the results. Every run submits real jobs under the deploy userid.

## Values to check in `envs/t01.yaml`

| Key | Value now | What it is |
|---|---|---|
| `USERGROUP` | `LWDUSER` | Everyone who uses LWD: transaction `LWDU` and the plan; placeholder |
| `SUBMITUSER` | `LWDSUBM` | Userid of the submit task; placeholder |
| `DEPLOYUSER` | `LWDDEPL` | Deploy userid of the demo environments; placeholder |
| `DB2GROUP` | `LWDT01` | Group of `SUBMITUSER` and `DEPLOYUSER`, with READ on the plan in `MDSNPN` |
| `DEMOACCESSGROUP`, `DEMOOWNERGROUP`, `DEMOAPPROVERGROUP` | `LWDDEMO`, `LWDOWNR`, `LWDAPPR` | Groups of the demo application; placeholders |
| `DEMOHLQ` | `LWDDEPL.DEMO` | Only goes into variables; the demo jobs write nothing |
| `ADMINRES`, `GROUPPREFIX` | `LWD.T01.ADMIN`, `LWD.T01.GRP` | FACILITY resources, per environment, as the environments share one RACF database |
| `JOBPREFIX` | `LT` | First two characters of job names; another environment needs another prefix |
| `JOBMSGCLASS` | `X` | Must be a class that keeps output, for SDSF and later S3; placeholder |
| `CICSTXN_USER`, `CICSTXN_ADMIN`, `CICSTXN_SUBMIT` | `LWDU`, `LWDA`, `LWDS` | Transactions |
| `CICSREGIONUSER`, `CICSDFLTUSER`, `ADMINGROUP`, `CICSCSD`, `CICSLST` | As CTF | From `ctfdlww/envs/t01.yaml` |
| `MAILFROM`, `MAILURL` | Placeholders | Not used yet |

The values the jobs use are also in the `SETTINGS` reftable (`SETTINGS.sql`), so they can be changed without a rebuild: `JOBPRFX`, `JOBCLASS`, `MSGCLASS`, `DB2*`, `LOADLIB`, `SUBMUSR`, `SUBMTXN`.

## To check on the first run

- **CVDA:** `LWDA992` compares `QUERY SECURITY`'s READ CVDA with 35 (`READABLE`) as an EQU. Check it against `DFHVALUE`.
- **`LWDA990` in batch:** `JSABJBNM` and `JSABJBID` give the job name and JES job ID, as `JSABUSID` gives the userid.
- **Optional fields:** a missing optional field arrives as binary zeros (`initWith 0x00`). The modules treat `NX'0000'` as empty; check that against how LWW maps a missing `startAfter`.
- **Trailing spaces:** `jcl` is a fixed `PIC X(32400)`, filled with spaces after the base64. The test strips them before decoding; LWW may already trim them.
