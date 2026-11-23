# Iteration 3: job output

Until now a run showed only how it ended (O, H, A), as the result step saw
it. This iteration collects the output of every job into DB2 (S3), so the UI
can show it (M4):
- the spool files of a run, with DD, step and procedure step names
- the steps of a run with their exact return codes or abend codes, and the
  job's return code
- three read endpoints: steps, spool files, and the text of a file in pages
- purging collected output after `OUTDAYS` days (S4, step 4)

Nothing here has been compiled or run yet.

## Why not the CICS writer

The design (M4) routed a copy of each job's output to a CICS external writer,
to be read with `SPOOLOPEN INPUT`. That interface hands CICS one data set at a
time and returns only a token: no job name, DD name or step name. Output could
only be matched to a run from its contents, and SPOOLFILES.DDNAME and
STEPNAME would stay empty. It would also need `SPOOL=YES` in the region.

So the scheduled job collects it instead, after the tick, with SDSF's REXX
interface. SDSF finds a job by its name, which is unique per run (`JOBPRFX` +
RUNID in base 36), and gives every data set with its DD, step and procedure
step name. The deployment jobs no longer need an OUTPUT statement, and the
settings `CICSNODE`, `CICSWTR` and `OUTCLASS` are gone.

## What is built

| Method and path | Wrapper | Module | Use case |
|---|---|---|---|
| GET `/jobSteps?runID=` | `LWDC215` | `LWDM215` | M3 |
| GET `/spoolFiles?runID=` | `LWDC216` | `LWDM216` | M4 |
| GET `/spoolText/{runID}?fileNo=` | `LWDC317` | `LWDM317` | M4 |

All three run under transaction `LWDU`. Who may see them is decided by
`LWDM311`, as for the deployment of the run. Steps and files come in pages of
20 (`stepNo_since`, `fileNo_since`).

`GET /spoolText` returns the lines after `lineNum_since`: as many whole lines
as fit, at most 300 and at most 24000 bytes of UTF-8, base64 encoded, so at
most 32000 characters (docs/04-api.md). `moreLines` `Y` means there is more:
call again with `lineNum_since` = `firstLineNum` + `lineCount` - 1.

The collector, in the scheduled job:

| Step of `LWDTICK` | Program | What it does |
|---|---|---|
| `TICK` | `tick.py` | As in iteration 2 |
| `OUTLIST` | `LWDM940` (COBOL, static SQL) | Purges output older than `OUTDAYS` days (P), sets runs that never reached JES to N, lists up to 20 runs to collect |
| `OUTGET` | `LWDR941` (REXX, SDSF) | Per run: finds the job on the ST panel, copies its data sets to a work data set |
| `OUTLOAD` | `LWDM945` (COBOL, static SQL) | Loads the work data set into SPOOLFILES, SPOOLLINES and JOBSTEPS, sets JOBRC, ABENDCODE and OUTPUTSTATUS C |

`OUTLIST` runs whatever the tick did. `OUTGET` only runs when `OUTLIST`
ended with RC 0, and `OUTLOAD` only when `OUTGET` did. Each run is committed
on its own, so a failure only costs the run being loaded; the next tick tries
it again.

Changed:

| Program or file | Change |
|---|---|
| `LLWDM212`, `LLWDM313` | `LINECOUNT` is now 4 bytes, since one field (`lineCount`) serves the JCL and a spool file of up to 50000 lines. Recompile `LWDM212`, `LWDC212`, `LWDM313` and `LWDC313`; the code is the same |
| `JCL/LWDTICK` | Steps `OUTLIST`, `OUTGET`, `OUTLOAD` |
| `JCL/RACF` | `DSNR` `BATCH` for `LWDSCHD`; a JESSPOOL profile for the deployment jobs' output |
| `DDL/SETTINGS` | Without `CICSNODE`, `CICSWTR` and `OUTCLASS` |
| `ZMAKE/DEPLOY.zmake` | Copies `REXX/*.rexx` to `{{EXECLIB}}`, a new library |

## Output status of a run

| OUTPUTSTATUS | When |
|---|---|
| W | The run is new, submitted or running, or ended and not collected yet |
| C | Collected by `LWDM945` |
| N | Never reached JES (result X), set by `LWDM940`; or not found in JES, set by `LWDM945` once the run ended more than `JOBMINS` minutes ago |
| P | Purged by `LWDM940` after `OUTDAYS` days; the run and its steps stay |

A job still in JES's input, conversion or execution queue counts as still
running: tried again next tick. That happens: the result step is the last
step, so the job ends a moment after the run does.

A run marked stuck (result T) without a result step is collected too, if its
job is in JES. That is how a JCL error becomes visible: its output, the
`JES: JCL ERROR` message on the run, and the JES job ID, which only the
result step would otherwise record.

## Steps and return codes

`LWDM945` takes the steps from the system messages in `JESYSMSG`, one step
per message, in order:

| Message | Step |
|---|---|
| `IEF142I ... COND CODE nnnn` | Executed, STEPRC nnnn |
| `IEF472I ... SYSTEM=sss USER=uuuu` | Abended: Ssss, or Uuuuu when SYSTEM is 000 |
| `IEF202I`, `IEF206I`, `IEF272I` | Not executed (FLUSHED Y): COND, IF, or after an abend |

These messages name a procedure step as well when the step called one. Which
of the two names is the step is checked against the names SDSF gave the
step's SYSOUT data sets; without those the first is taken as the step.
`PGMNAME` stays empty: the program isn't in these messages.

The job's return code comes from SDSF's return code column: `CC nnnn` gives
JOBRC, `ABEND Sxxx` or `ABEND Uxxxx` gives ABENDCODE, anything else (`JCL
ERROR`, `CANCELED`, ...) becomes the run's JOBMESSAGE, unless it has one
already. Without it, JOBRC is the highest step RC and ABENDCODE the first
abend of a step.

## Lines

- Trailing blanks are stripped, and the carriage control character when the
  data set has ASA control (from `LISTDSI`).
- Lines are cut off at 255 characters (SPOOLLINES.LINETEXT).
- At most `OUTLINES` lines per run (t01: 50000). The file where that runs out,
  and every file after it, gets TRUNCATED Y; the files after it have no lines.
- `JESMSGLG`, `JESJCL` and `JESYSMSG` come first, so the step messages are
  always in.

## Setting it up on t01

1. **`envs/t01.yaml`:** check `JESNODE` and `EXECLIB` (below).
2. **DDL:** `python python/deploy.py DEPLOY_DDL`, then run `SETTINGS` with
   `RUNDDL`. It deletes and rewrites all settings, so the old `CICSNODE`,
   `CICSWTR` and `OUTCLASS` rows go.
3. **Build and deploy:** `. ./setenv`, `build`, then `python python/deploy.py`.
   New: `LWDM215`, `LWDM216`, `LWDM317`, their wrappers, `LWDM940`,
   `LWDM945`, and the library `{{EXECLIB}}` with `LWDR941`.
4. **CICS:** install the new programs and NEWCOPY the changed ones:
   - new: `LWDC`/`LWDM` 215, 216 and 317
   - changed: `LWDC212`, `LWDM212`, `LWDC313`, `LWDM313`

   `LWDM940` and `LWDM945` run in batch, from the load library.
5. **RACF:** submit `RACF` again. New:
   - `DSNR` `DBY1.BATCH` for `LWDSCHD`, for `DSN RUN`
   - JESSPOOL `{{JESNODE}}.*.LT*.**` with READ for `LWDSCHD`: the output of
     every deployment job, whatever deploy userid it ran under. Needs
     `SETROPTS GENERIC(JESSPOOL)`

   Not in the job, as sites protect SDSF differently: `LWDSCHD` needs SDSF
   authority to the ST panel and to browse output (`SA`). Also READ on
   `{{LOADLIB}}` and `{{EXECLIB}}`.
6. **LWW:** copy both specs from `openapi/` to `remoteOASDir`, then
   `python python/processYAML.py` and `python python/uploadLWW.py`.
7. **`LWDTICK`:** submit it once by hand and read `SYSTSPRT` of `OUTGET` and
   `SYSOUT` of `OUTLIST` and `OUTLOAD`.

## Trying it

`python/testIteration3.py` signs in as the deployer, then:
1. deploys `V1.0.0` to DEV
2. waits until `LWDTICK` has collected the output of both runs (up to 20
   minutes), as the collector only runs in that job
3. for job 1: lists steps and files, reads every file in pages and checks the
   line counts, and checks step `SHOW` RC 0, result step `LWDRSO` executed,
   `LWDRSA` and `LWDRSH` not, job RC 0
4. the same for job 2, step `SETRC` RC 0
5. asks for a spool file that doesn't exist: 404 `04 01`
6. deploys `V1.0.1-BAD`: job 2 fails
7. checks step `SETRC` RC 8, `LWDRSH` executed, job RC 8
8. cancels it, so DEV is free

Purging takes `OUTDAYS` days with the t01 settings. To try it, lower
`OUTDAYS` in SETTINGS to 0 for a moment and run `LWDTICK`.

## Values to check in `envs/t01.yaml`

| Key | Value now | What it is |
|---|---|---|
| `JESNODE` | `N1` | JES2 node name, the first qualifier of JESSPOOL profiles (`$D NODE`); placeholder |
| `EXECLIB` | `YINCIC.CPSM.T01.LWD.EXEC` | REXX library of `LWDTICK`; `tgthlq` of deploy.py + `.EXEC` |
| `OUTPUTDAYS`, `OUTPUTMAXLINES` | 90, 50000 | Settings `OUTDAYS` and `OUTLINES`, as before |

## To check on the first run

- **SDSF names:** `LWDR941` uses the ST columns `JNAME`, `JOBID`, `QUEUE` and
  `RETCODE`, and the data set columns `DDNAME`, `STEPN` and `PROCS`, with
  `ISFACT ... PARM(NP ?)` and `PARM(NP SA)`. If SDSF gives other names or
  values at this level, `SYSTSPRT` of `OUTGET` shows it.
- **The queue:** a job counts as still running while `QUEUE` starts with
  `EXEC`, `INPUT`, `CONV` or `SETUP`.
- **The return code column:** the formats `CC 0000` and `ABEND S0C4`.
- **Step names:** the order of step and procedure step in `IEF142I` for a
  step that calls a procedure, when the step has no SYSOUT data sets. The
  demo jobs call no procedures.
- **Not executed:** whether skipped `IF` steps give `IEF206I` at this level,
  so `LWDRSA` and `LWDRSH` show as FLUSHED.
- **Code page:** the lines are read as CCSID 037 (the compile option), so a
  few special characters may differ when the spool is 1047.
- **Space:** `&&OUTDATA` holds up to 20 runs of `OUTLINES` lines.
- **Visibility:** a job `LWDSCHD` may not see counts as not found, and its
  run ends up N after `JOBMINS` minutes. Check RACF before the first real
  deployments.

## Not built yet

- **Mail (S5)**, and the email refresh of S4.
- **The admin API**, template editing and variables.
- **`GET /deployments`**, the list.
- **Earlier JCL errors:** a job that fails with a JCL error has no result
  step, so its run stays S until it is stuck after `JOBMINS` minutes. The
  collector could notice it sooner, as it sees the job in JES.
