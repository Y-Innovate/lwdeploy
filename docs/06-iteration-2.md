# Iteration 2: approval, scheduling, retry and continue

Iteration 1 could deploy, but a deployment needing approval could only be
cancelled. A queued one waited forever, and a failure ended with a cancel.
This iteration closes those gaps:
- approval with N approvers (AP1, AP2)
- the scheduler (S4) as a REST tick, with stuck runs and expiry
- retry and continue after a failure (D4)
- three read endpoints for the history: decisions, events and runs

Nothing here has been compiled or run yet.

## What is built

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| GET `/approvalRequests` | `LWDC290` | `LWDM290` | AP1 |
| GET `/approvals` | `LWDC218` | `LWDM218` | M3, AP2 |
| POST `/approvals` | `LWDC418` | `LWDM418` | AP2 |
| POST `/retries/{deplID}` | `LWDC511` | `LWDM511` (T) | D4 |
| POST `/continuations/{deplID}` | `LWDC511` | `LWDM511` (K) | D4 |
| POST `/cancellations/{deplID}` | `LWDC511` | `LWDM511` (C), changed | D3 |
| GET `/deploymentEvents` | `LWDC219` | `LWDM219` | M3 |
| GET `/jobRuns` | `LWDC214` | `LWDM214` | M3 |
| POST `/schedulerTicks` | `LWDC930` | `LWDM930` | S4 |

The user paths run under transaction `LWDU`. `POST /schedulerTicks` is a new
path with a new tag, `scheduler`, and runs under its own transaction `LWDQ`.

**Program numbers.** CTF's rule still holds: the first digit is the kind, the
last two the table. Two cases needed an exception:
- **Cancel, retry and continue** are all actions on table 011, so they share
  `LWDC511`/`LWDM511`, as CTF's `CTFC510` serves four paths. LWW sets
  `DEPLACTION` per path with a `constant` mapping, as in CTF.
- **The approval requests** are a list of deployments filtered for the
  approver, not a plain table list. They take `290`, as CTF's `CTFM290`.

Changed programs:

| Program | Change |
|---|---|
| `LWDM411` | Starts a deployment through the new `LWDSTRP` instead of its own `R400-START` and `R410-SUBMIT-SETTINGS` |
| `LWDM311` | `canRetry` is Y for a member when the deployment is F |
| `LWDM915` | `R310` uses the shared `R670-DEPL-SUCCEEDED`. A late result of a run the scheduler set to T is still recorded on the run (RC 4) |

New and changed copybooks:

| Copybook | What it holds |
|---|---|
| `LWDSTRW`, `LWDSTRP` | Start a deployment: take the environment, go to U, create a run of the first job with a token (`R700`). Submit one job (`R710`) and read the submit settings (`R720`). Start the oldest due Q deployment of an environment just freed (`R730`) |
| `LWDDEPP` | New: `R670-DEPL-SUCCEEDED` (deployment S, inventory, environment free, event S), shared by the result step and continue |

## Generator changes

`genoas.py` adds:
- `POST /schedulerTicks` with its response fields
- the `scheduler` tag
- an optional `commentText` on retry, because D4 records why

`genlww.py` now supports several paths on one program:
- `const` sets a field per path.
- `sfx` keeps the names of their LWW steps apart (`LWDC511T_ID`).
- `desc` is the wrapper's header line.
- The generator checks that paths sharing a program also share its IO area exactly.

It also prefixes a list field whose name equals a field outside the list. For
example, `RUN-JOBNO` in `LLWDM214`, where `JOBNO` is also the query field.
Otherwise a reference to `JOBNO` would be ambiguous in COBOL. No earlier
copybook changed because of this.

## How a deployment starts now

Every request that can start a deployment does so at once, in the same unit
of work. The wrapper then starts the submit task, as in iteration 1. At most
one run goes to the wrapper per request.

| Event | What starts | Program |
|---|---|---|
| Request without approval, due, environment free | That deployment | `LWDM411` |
| The N-th approval, due, environment free | That deployment | `LWDM418` |
| A cancel frees the environment | Its oldest due Q deployment | `LWDM511` C |
| Retry | The failed job again | `LWDM511` T |
| Continue | The next job; with none left the deployment succeeds and the environment's oldest due Q deployment starts | `LWDM511` K |
| The last job succeeds (result step, batch) | Nothing: the next tick starts the queue | `LWDM915` |
| `startAfter` reached, environment busy before | Nothing: the next tick | `LWDM930` |

A cancel or continue can start someone else's deployment, which was already
requested and approved. Its U event and run then carry the userid of whoever
cancelled or continued.

## The scheduler (M10)

A batch job calls `POST /schedulerTicks` every few minutes. Each call:
1. expires W deployments older than `APPRHRS` hours: status E, jobs K, event E
2. fails runs without a result after `JOBMINS` minutes. A submitted run gets
   result T; a run never submitted (still N) gets X. Its job and deployment
   become F, and the deployment keeps the environment, as any failure does.
3. starts the oldest due Q deployment whose environment is free, and answers
   `moreDue` Y if another could start
4. writes the time into setting `LASTTICK`, so a stopped scheduler can be seen

Steps 1 and 2 handle at most 50 rows per tick. `tick.py` calls again while
`moreDue` is Y, at most `maxCalls` (20) times.

Only the `SCHEDUSR` setting's userid may tick. It's checked in COBOL, on top
of RACF's check on transaction `LWDQ`.

**Batch side.**
- `JCL/LWDTICK` runs `python/tick.sh` under BPXBATCH, with `USER=LWDSCHD`.
- `tick.sh` sets up Python and the venv, then runs `tick.py`.
- `tick.py` signs in to Entra with client credentials (through
  `MyRequests.getBearerToken`), calls the tick, and logs one line per call.
  It exits 0 when every call succeeded and 8 otherwise.
- The job is plain JCL with a return code, so any workload scheduler can run
  it. In IZWS, make it a cyclic job without dependencies.

**Configuration.** `tick.json` is readable by `LWDSCHD` only. It holds:
- the host and the token URL
- the path of the credentials file
- optionally, a CA bundle for LWW's certificate

The credentials file has the same format as `uploadLWW.py` uses. Your JWT
signing (client assertion) can replace the secret later; only `getToken()`
in `tick.py` changes.

**Stuck runs and retries.** A run marked T may still be running in JES. If
its job ends later, the result step records the real outcome on the run only.
A retry of a T run while the job still runs would give two runs at once, so
`JOBMINS` must be longer than the longest deployment job.

## Approval (AP1, AP2)

- `POST /approvals` with `decision` A or R. The user must be in the approver
  group copied into the deployment, checked live (M7). The requester can't
  decide (`08 55`), and neither can someone who decided already (`08 55`,
  from the primary key of APPROVALS).
- **Approve:** one `UPDATE` counts the approval and sets Q at N, with
  `DEPLSTATUS = 'W'` in its `WHERE`. So two approvers at once can't both miss
  N or overshoot it. If the deployment is due and its environment is free,
  it starts in the same call and the answer says U.
- **Reject:** a comment is required (`08 05`). The deployment becomes J and
  its jobs K.
- **The list:** `GET /approvalRequests` uses the same filter as
  `approvalsWaiting` in `GET /me`, through the cached groups. Oldest first,
  paged by `deplID_since`.
- **The seed:** the demo PRD now needs two approvals. `SEEDITR2.sql` makes
  that change in an environment seeded in iteration 1.

## Retry and continue (D4)

- Who: a deployer, meaning a member who is also in the deployer group if the
  environment has one. When: F. Both use the frozen JCL, so no new approval.
- **Retry:** optional comment. The failed job goes back to W, the deployment
  to U, event T, and a new run with a token goes to the submit task. The
  earlier runs stay readable through `GET /jobRuns`.
- **Continue:** comment required: it is the job's `SKIPREASON`. The job
  becomes K, event K. Then:
  - the next waiting job is submitted, or
  - with none left, the deployment succeeds and the inventory gets the
    version. The user said the problem was fixed by hand.
- **Cancel during U** now also fails a run that the submit task hasn't claimed
  yet (X), so its token can't submit the job after the cancel.

## DB2 plans

Unchanged: plan `LWDT01` with `PKLIST(LWDT01.*)` picks up the new packages.
Transaction `LWDQ` gets its own `DB2ENTRY` on that plan.

## Setting it up on t01

1. **`envs/t01.yaml`:** check the new values (below).
2. **DDL:** `python python/deploy.py DEPLOY_DDL`. Then with `RUNDDL`, run
   `SETTINGS`, which can be run again. Run `SEEDITR2` only if the demo was
   seeded in iteration 1.
3. **Build and deploy:** `. ./setenv`, `build`, then `python python/deploy.py`.
   This compiles the new and changed programs and binds their packages.
4. **CICS:** define transaction `LWDQ` and `DB2ENTRY` `LWDQ` from `CICSCSD`.
   Run only those two `DEFINE`s: the others exist already. Then install them,
   and NEWCOPY the changed programs:
   - `LWDC511`, `LWDM311`, `LWDM411`, `LWDM511`
   - the new `LWDC`/`LWDM` 214, 218, 219, 290, 418 and 930

   `LWDM915` runs in batch, from the load library.
5. **RACF:** submit `RACF` again. ADDUSER, CONNECT and RDEF give messages for
   what exists already. New:
   - userid `LWDSCHD`, with an OMVS segment (`AUTOUID` needs
     `BPX.NEXT.USER`)
   - transaction `LWDQ` for `LWDSCHD` only
   - `DFHDB2.AUTHTYPE.LWDQ`
   - surrogate `LWDSUBM.DFHSTART` for `LWDSCHD`
   - `LWDSCHD.SUBMIT` and `BPX.SRV.LWDSCHD` in `SURROGAT`, for group
     `SCHEDGROUP` (`LWDSCHG`), which must exist. Its members may submit JCL
     with `USER=LWDSCHD` and switch to it in USS with `su -s lwdschd`.
     Connect the workload scheduler's userid to it too.
6. **LWW:**
   - Copy both specs from `openapi/` to `remoteOASDir`.
   - `python python/processYAML.py`, then `python python/uploadLWW.py`. The
     placeholder `LWWAdmin/API/v1/schedulerTicks` assigns `LWDQ`.
   - Map the tick's Entra application to `LWDSCHD`.
7. **The tick on USS:**
   - `python python/deploy.py` (step 3) copies `tick.py`, `tick.sh`,
     `Globals.py` and `MyRequests.py` to `TICKDIR` (`/var/lwd/t01/tick`).
     `python python/deploy.py DEPLOY_TICK` copies only those. The deployer
     needs write access there, and `LWDSCHD` read access; the code holds no
     secrets.
   - Once, as `LWDSCHD` (`su -s lwdschd`): make a venv with `requests` at `TICKVENV`, and write
     `tick.json` and the credentials file (format in `tick.py`) in
     `/u/lwdschd`, readable by `LWDSCHD` only.
   - Try `LWDTICK` once by hand, then schedule it.
8. **The approvers:** two userids in `USERGROUP` and `DEMOAPPROVERGROUP`, not
   the deployer.

## Trying it

`python/testIteration2.py [tick.json]` signs in as the deployer and both
approvers, then:
1. runs `V1.0.0` through DEV and TST, for PRD's promotion gate
2. requests PRD:
   - checks the approval list
   - checks that the requester can't approve
   - first approval: still W
   - checks that the same approver can't approve twice
   - second approval: started at once
   - events R A A Q U S
3. requests PRD again and rejects it, first without a reason (`08 05`), then
   with one
4. deploys `V1.0.1-BAD` to DEV: it fails, the retry fails again, and job 2
   has two runs
5. continues without a reason (`08 05`), then with one: job 2 is K with its
   reason, the deployment succeeds, and the events are R U F T F K S
6. builds a queue on DEV: the second deployment stays Q after the first
   succeeds, until a tick starts it
7. leaves a failed deployment holding DEV with another queued behind it.
   Cancelling the failed one starts the queued one.
8. schedules TST one minute ahead, and a tick starts it once its time has
   come

With `tick.json` the test ticks itself, as the scheduler's Entra application.
Without it, the test waits up to 15 minutes for the scheduled job.

Expiry and stuck runs take hours with the t01 settings. To try them, lower
`APPRHRS` or `JOBMINS` in SETTINGS for a moment, then tick.

## Values to check in `envs/t01.yaml`

| Key | Value now | What it is |
|---|---|---|
| `SCHEDUSER` | `LWDSCHD` | Userid of the scheduler, also setting `SCHEDUSR`; placeholder |
| `SCHEDGROUP` | `LWDSCHG` | Group whose members may act as `SCHEDUSER`: submit with `USER=`, `su -s` in USS; placeholder |
| `CICSTXN_SCHED` | `LWDQ` | Transaction of `POST /schedulerTicks` |
| `TICKHOME` | `/u/lwdschd` | Home directory of `LWDSCHD` (OMVS segment) |
| `TICKDIR` | `/var/lwd/t01/tick` | Where deploy.py copies `tick.sh` and `tick.py`; a plain path, not rendered |
| `TICKCONFIG` | `/u/lwdschd/tick.json` | The tick's configuration |
| `PYTHONHOME`, `TICKVENV` | `/usr/lpp/IBM/cyp/v3r13/pyz`, `/u/lwdschd/venv` | Python, and a venv with `requests` |

## To check on the first run

- **LWW's `constant` mapping:** it fills `DEPLACTION` for the three paths of
  `LWDC511`, as it fills `PROVACTION` in CTF.
- **The tick request:** `POST /schedulerTicks` has no request body; `tick.py`
  sends `{}`.
- **BPXBATCH's return code:** the shell's exit status, either 8 or 2048 on
  failure depending on the z/OS level. Either way the scheduler sees a
  failure.
- **Sign-in and identity:** the Entra application's token is accepted for
  `LWDQ`, and LWW maps it to `LWDSCHD`. Then `GET /me` as the tick would show
  `LWDSCHD`.
- **The cancel message:** the SQL literal `'Cancelled before submission'` in
  `LWDM511` goes into a VARGRAPHIC column, as the seed's literals do.
- **Concurrency:** an approval or cancel and a tick at the same moment. The
  environment `UPDATE` with `ACTIVEDEPLID IS NULL` decides who starts, and
  the loser gives the environment back (`R700`).

## Not built yet

- **Job output (S3):** built in [iteration 3](07-iteration-3.md), with the
  output purge of S4, and without an OUTPUT statement.
- **Mail (S5)**, and the email refresh of S4.
- **The admin API**, template editing and variables. Without the admin API,
  N, the approver group and the deploy userid are changed in DB2 directly.
- **`GET /deployments`**, the list.
- `LASTTICK` isn't shown anywhere yet. The admin settings list (A5) will show
  it.
