# REST API

A guide to [`openapi/lwd_1.0.0.yaml`](../openapi/lwd_1.0.0.yaml), the public
contract of the LWD backend, with base path `/lwdeploy/API/v1`. It has 58 operations:
1 public (`POST /token`), 43 user, 12 admin, 1 for the scheduler and 1 for the
result step. The LWW processing steps
(`lwd_2_1.0.0.yaml`) and the copybooks follow per iteration, as in CTF: an
operation refers to its steps there once it is built
([05-iteration-1.md](05-iteration-1.md)).

## Conventions

These follow `ctfdlww`, so petshop and LWW:

- **Envelope:** every response body has `retCode`, `reasonCode` and
  `infoMessage`. The exception is `POST /token`, LWW's own `LWWADPLI`, which
  returns only the token.
- **Paths:** at most one ID, always at the end of the path. Other keys go in the
  query string, for example `/deploymentJcl/{deplID}?jobNo=2`.
- **Lists:** at most 20 rows, one array per response, never nested. To get the
  next page, pass the last row's key as `*_since`. Fewer than 20 rows means the
  end. Lists that are newest first continue with lower keys.
- **Fits in one page:** an application has at most 20 environments and at most
  20 active job templates, so `GET /environments` and `GET /templates` never
  page, and a deployment has at most 20 jobs.
- **Filters:** optional `*_filter` query parameters.
- **Text:** every string has a `maxLength` that matches its DB2 column.
- **Timestamps:** strings in DB2 format, `2026-01-01-00.00.00.000000`.
- **Empty values:** an empty string means NULL; LWW returns an empty
  variable-length field as `null`, and clients treat `null` and `""` alike.
- **Empty numbers:** keys use 0 for "none" (`envID`, `versionID`,
  `activeDeplID`, ...). Return codes use -1 for "not known", because 0 is a real
  return code.
- **Missing request fields:** optional, so marked `required: false` in the
  mappings: every description field, `startAfter` and `requestNote` of a
  deployment, `envID` and `versionID` of a new variable, `commentText` of an
  approval, a cancellation and a retry, `approverGroup` and `deployerGroup` in the
  environment controls. A missing text field is empty, a missing number 0.
- **Single characters:** codes such as `Y`/`N` are explained in the field's
  description.
- **Flags for the UI:** `is*` and `can*` fields (`isOwner`, `canDeploy`,
  `canApprove`, `canCancel`, `canRetry`) tell the UI what to show. The backend
  checks again on every change.

## JCL and job output: base64

LWW maps only single fields from a request body, and arrays only into
responses. JCL and output are many lines, so they travel as base64 text:

| What | Direction | How |
|---|---|---|
| Template JCL (`POST /templateJcl/{templateID}`) | Request | `multipart/form-data` with the fields `jcl` (base64) and `changeNote`. LWW passes only `templateID`; the wrapper `LWDC410` reads both fields with `EXEC CICS WEB READ FORMFIELD` and passes them to `LWDM410` (the DB2 modules have no CICS translator) |
| Template JCL, frozen JCL | Response | One field `jcl`, at most 32400 characters |
| Job output (`GET /spoolText/{runID}`) | Response | One field `spoolText` with as many whole lines as fit in 32000 characters, at most 300 lines; `moreLines` and `lineNum_since` page through the file |

Both are base64 of UTF-8 text, with lines separated by LF. On the way in, CR
before LF is dropped. A template has at most 300 lines of at most 80
characters, which is where the 32400 comes from (300 x 81 bytes, as base64).

**Size cap.** Channels and containers would carry far more, but every request
holds its fields several times in CICS storage: in the container, in LWW's IO
area and in the module's working storage. So no field is bigger than about 32
KB, and no request or response much bigger than that. Larger output is paged.

In COBOL:

1. Decode or encode base64 (a small routine, as `CTFA990`/`CTFA991` are for
   CTF).
2. Convert between UTF-8 and the national (UTF-16) DB2 columns with
   `FUNCTION NATIONAL-OF(..., 1208)` and `FUNCTION DISPLAY-OF(..., 1208)`.
3. Split at LF into TEMPLATELINES or join JCLLINES and SPOOLLINES with LF.

In the copybooks, these fields are `PIC X(n)` (`CHARARRAY037`): the base64
alphabet is the same in EBCDIC and ASCII, so LWW's conversion can't damage it.

## Access

Each access level gets its own CICS transaction, assigned per URI in LWW.

| Tag | Who | Transaction | Userid | Check in COBOL |
|---|---|---|---|---|
| `public` | Anyone | LWW's own, for `POST /token` | | None |
| (web UI) | Anyone | `LWDP`, only for the files that load before sign-in: `index.html`, `assets/`, the login folder; no API path. Its plan `LWDT01P` holds only LWW's packages (iteration 5) | CICS default userid | None |
| `user` | Any signed-in user | `LWDU` | The user's RACF userid | The role the operation needs, per application or environment (below) |
| `admin` | Administrator | `LWDA` | The user's RACF userid | `QUERY SECURITY` on the `ADMINRES` setting (`LWD.T01.ADMIN`) |
| `scheduler` | The scheduled tick job | `LWDQ` | The scheduler's userid (`LWDSCHD`), mapped from its Entra application | The CICS userid must be the `SCHEDUSR` setting |
| `job` | The result step of a deployment job | `LWDJ` | The deploy userid (`LWDDEPL`), mapped from its Entra application (`DEPLAPP`) | The CICS userid must be the deploy userid of the run's deployment |

How COBOL decides a role, with the FACILITY profile `<GRPPRFX>.<group>` of
[03-data-model.md](03-data-model.md#access-through-facility-profiles):

| Role in the tables below | Check |
|---|---|
| Member | Access group of the application |
| Owner | Owner group of the application |
| Approver | Approver group of the environment, or of the deployment for AP2 (the group copied at request time) |
| Deployer | Access group of the application, and the deployer group of the environment if it has one |
| Requester | DEPLOYMENTS.CREATEDBY is the CICS userid |
| "Member, owner, approver" | Any one of these for the application. Approvers see an application only through deployments waiting for or decided by them, and its environments and versions |

Rules for the backend:

- The user always comes from the CICS userid. No request can name who is acting.
- The CICS default userid must have no access to `LWDU`, `LWDA` or `LWDQ`;
  there are no anonymous paths. It may use `LWDP`, which serves files only. Only the scheduler's userid may use `LWDQ`.
- Administrators may read everything through the `user` paths too (A4), but
  only change things through `/admin` paths, unless they also have the role.
- A user without any role in an application gets `04 01` not found, not `08 50`,
  so the API doesn't reveal which applications exist.
- LWW logging must leave out request bodies on `/token`, because they carry
  passphrases.

## Status and reason codes

The CTF convention, with `08 5x` for LWD's rules:

| Return, reason | HTTP | Meaning |
|---|---|---|
| `00 00` | 200, 201 | OK |
| `04 01` | 404 | Not found, or no role in the application |
| `08 0x` | 400 | Invalid input |
| `08 11` | 409 | Duplicate |
| `08 12`, `21`, `32`, `42` | 500 | SQL error |
| `08 13`, `33` | 404 | Missing parent |
| `08 31`, `41` | 404 | Update or delete of a missing key |
| `08 50` | 403 | Not allowed: role missing, or not an administrator |
| `08 53` | 409 | Not possible in this state: deployment status, version used, still in use (the message says what) |
| `08 54` | 409 | Promotion gate: the version didn't succeed in the previous environment |
| `08 55` | 403 | Own request, or already decided by this user |
| `08 56` | 400 | JCL refused: a JOB statement, `USER=`, a JES2 or JES3 statement, a line too long; the message names the line |
| `08 57` | 400 | Variable without a value at D1; the message names the first |
| `08 58` | 400 | Form field missing, or not valid base64 or UTF-8 |
| `08 59` | 409 | Not ready to deploy: no deploy userid, no approver group, no templates, or a template without JCL |
| `08 90` | 500 | Security check or encoding routine failed |
| `08 91` | 500 | Local wrapper could not reach the DPL program (`LWDW410` LINK to `LWDC410` failed) |

A queued deployment that waits for its environment is not an error:
`POST /deployments` returns 201 with `deplStatus` `Q`.

## Endpoints

The system use cases S1-S5 run in CICS or batch. Two have an endpoint:
S4, `POST /schedulerTicks`, which the scheduled job calls (iteration 2), and
S2, `POST /jobResults`, which the result step of every deployment job calls
(iteration 4). Each has its own tag and CICS transaction: `scheduler` for the
scheduler's userid, `job` for the deploy userids.

### Sign-in and profile

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| POST | `/token` | Sign in with RACF userid and passphrase | Anyone | U1, O4 (CI) |
| GET | `/me` | Get the signed-in user | Anyone | U1 |
| PUT | `/me` | Update own notification settings | Anyone | U2 |

### Applications and environments

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| GET | `/applications` | List my applications | Member, owner, approver | M1 |
| GET | `/applications/{appID}` | Get an application | Member, owner, approver | M1 |
| GET | `/environments` | List the environments of an application, in order, with the inventory | Member, owner, approver | M1, M2, O1 |
| GET | `/environments/{envID}` | Get an environment | Member, owner, approver | M2, O1 |
| POST | `/environments` | Add an environment | Owner | O1 |
| PUT | `/environments/{envID}` | Update name, order and promotion gate | Owner | O1 |
| DELETE | `/environments/{envID}` | Delete an environment without deployments | Owner | O1 |

### Versions and variables

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| GET | `/versions` | List versions, newest first | Member, owner, approver | M2, D1, O4 |
| GET | `/versions/{versionID}` | Get a version | Member, owner, approver | M2, O4 |
| POST | `/versions` | Register a version | Owner, CI | O4 |
| PUT | `/versions/{versionID}` | Update a version never used | Owner | O4 |
| DELETE | `/versions/{versionID}` | Delete a version never used | Owner | O4 |
| POST | `/versionRetirements/{versionID}` | Retire a version | Owner | O4 |
| GET | `/variables` | List the variables of one level: application, environment or version | Member, owner, approver | O1, O3, O4 |
| POST | `/variables` | Add a variable | Owner | O1, O3, O4 |
| PUT | `/variables/{varID}` | Update a variable | Owner | O1, O3, O4 |
| DELETE | `/variables/{varID}` | Delete a variable | Owner | O1, O3, O4 |

### Job templates

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| GET | `/templates` | List the job templates, in order | Member, owner, approver | O2 |
| GET | `/templates/{templateID}` | Get a job template | Member, owner, approver | O2 |
| POST | `/templates` | Add a job template, still without JCL | Owner | O2 |
| PUT | `/templates/{templateID}` | Update name, order and highest RC | Owner | O2 |
| DELETE | `/templates/{templateID}` | Delete a job template; its history stays | Owner | O2 |
| GET | `/templateRevisions` | List the revisions of a template, newest first | Member, owner, approver | O2 |
| GET | `/templateJcl/{templateID}` | Get the JCL of a template revision | Member, owner, approver | O2 |
| POST | `/templateJcl/{templateID}` | Save new JCL as the next revision | Owner | O2 |

### Deployments

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| GET | `/deployments` | List deployments, newest first: all of an application for a member, owner or administrator, only the decided ones for an approver; without `appID` only the own requests (`requestedBy_filter` = own userid, else `08 01`) | Member, owner, approver | M3 |
| GET | `/deployments/{deplID}` | Get a deployment | Member, owner, approver | M3, D2, AP2 |
| POST | `/deployments` | Request a deployment | Deployer | D1 |
| POST | `/cancellations/{deplID}` | Cancel a deployment | Requester, deployer | D3 |
| POST | `/retries/{deplID}` | Submit the failed job of a deployment again | Deployer | D4 |
| POST | `/continuations/{deplID}` | Skip the failed job, with a reason, and go on with the next | Deployer | D4 |
| GET | `/deploymentJobs` | List the jobs of a deployment with their latest run | Member, owner, approver | M3, D2 |
| GET | `/deploymentJcl/{deplID}` | Get the frozen JCL of a job of a deployment | Member, owner, approver | M3, AP2 |
| GET | `/deploymentEvents` | List the history of a deployment | Member, owner, approver | M3 |

### Approvals

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| GET | `/approvalRequests` | List the deployments waiting for my approval, oldest first | Approver | AP1 |
| GET | `/approvals` | List the decisions on a deployment | Member, owner, approver | M3, AP2 |
| POST | `/approvals` | Approve or reject a deployment | Approver | AP2 |

### Runs and output

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| GET | `/jobRuns` | List the runs of a job of a deployment | Member, owner, approver | M3 |
| GET | `/jobSteps` | List the steps of a run | Member, owner, approver | M3 |
| GET | `/spoolFiles` | List the collected spool files of a run | Member, owner, approver | M4 |
| GET | `/spoolText/{runID}` | Get a part of a spool file | Member, owner, approver | M4 |

### Scheduler and result step

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| POST | `/schedulerTicks` | One tick of the scheduler: expire, mark stuck runs, start one due deployment | Scheduler | S4 |
| POST | `/jobResults` | The result of a run, from the result step of its job; the next job is submitted | Deploy userid | S2 |

`POST /jobResults` answers `00 01` when the result came after the scheduler
had marked the run stuck: it is recorded on the run only.

### Admin

| Method | Path | What it does | Who | Use cases |
|---|---|---|---|---|
| GET | `/admin/applications` | List all applications | Admin | A1, A4 |
| POST | `/admin/applications` | Create an application | Admin | A1 |
| GET | `/admin/applications/{appID}` | Get an application | Admin | A1 |
| PUT | `/admin/applications/{appID}` | Update an application | Admin | A1 |
| DELETE | `/admin/applications/{appID}` | Delete an application without deployments | Admin | A1 |
| PUT | `/admin/environmentControls/{envID}` | Set deploy userid, approval and deployer group | Admin | A2 |
| GET | `/admin/deployments` | List deployments of all applications, newest first | Admin | A4 |
| POST | `/admin/stuckRuns/{runID}` | Mark a submitted run stuck: it fails, with its job and deployment | Admin | A4 |
| GET | `/admin/refTables` | List allowed RACF groups, deploy userids or settings | Admin | A3, A5 |
| POST | `/admin/refTables` | Create a reference entry | Admin | A3 |
| PUT | `/admin/refTables/{tableID}` | Update a reference entry | Admin | A3, A5 |
| DELETE | `/admin/refTables/{tableID}` | Delete a reference entry not in use | Admin | A3 |

## Scenarios walked through

| Scenario | Calls |
|---|---|
| CI registers a build | `POST /token` with the service userid, `POST /versions`, `POST /variables` with `versionID` for version variables |
| Deploy to TST without approval | `GET /versions?appID=`, `POST /deployments` (201, `Q`), poll `GET /deployments/{id}` and `GET /deploymentJobs?deplID=` |
| Deploy to PRD with 2 approvals | `POST /deployments` (201, `W`); approver 1 and 2 each `GET /approvalRequests`, `GET /deploymentJcl/{id}?jobNo=`, `POST /approvals`; the second answer has `deplStatus` `Q` |
| Approver tries own request | `POST /approvals` gives 403 with `08 55` |
| Job 2 of 3 fails | `GET /jobRuns?deplID=&jobNo=2`, `GET /spoolFiles?runID=`, `GET /spoolText/{runID}?fileNo=`, then `POST /retries/{deplID}` or `POST /continuations/{deplID}` |
| Owner changes a template | `GET /templateJcl/{id}`, edit, `POST /templateJcl/{id}` as multipart; deployments already requested keep their frozen JCL |
| Gate not passed | `POST /deployments` to PRD with a version never in ACC gives 409 with `08 54` |

## Toward the copybooks

The copybooks follow from the schemas, so `lwd_2_1.0.0.yaml` can be written per
iteration without changing this contract:

| Schema | Copybook | LWW field type |
|---|---|---|
| String up to 30, codes, timestamps | `PIC N(n)` | `CHARARRAY1200` |
| Longer text (names, descriptions, comments) | `49` level length + `PIC N(n)` | `VARCHAR1200` |
| Base64 (`jcl`, `spoolText`) | `PIC X(n)` | `CHARARRAY037` |
| Integer | `PIC S9(9) COMP-5`, or `S9(4)` for counts, order, RC and revision | `UI4`, `UI2` |
| List | `xxx-COUNT PIC S9(4) COMP-5` + `xxx-ENTRY OCCURS 20 DEPENDING ON xxx-COUNT` | `GROUPDEPENDSON` |

Every module copybook starts with `RETURNCODE`, `REASONCODE` and `INFOMESSAGE`,
then the request fields (query, path, body), then the response fields, as
`LCTFM202` does.

## Settled with LWW

- **Big fields:** channels and containers carry them; the cap above is LWD's own
  choice, for CICS storage.
- **Form fields:** CICS parses the `multipart/form-data` body, so
  `WEB READ FORMFIELD` is transparent: the wrapper `LWDC410` just asks for
  `jcl` and `changeNote` by name.
- **Email:** not part of the API. It comes from RACF (`WAEMAIL`), refreshed by
  the scheduled batch (S4, M8), so `GET /me` returns it read-only.
