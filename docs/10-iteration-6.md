# Iteration 6: owners and administrators

Since iteration 5, members, deployers and approvers work in the web UI. Owners
and administrators still work in DB2:
- **Administrators** create applications, set the groups and environment
  controls, keep the allowlists and change settings with SQL.
- **Owners** add environments, edit job templates and variables, and change
  versions the same way.

So a new application can't be put under LWD without someone who can update
the tables.

This iteration builds the rest of the contract for those two roles, and their
screens:
- **Administrators** (A1-A5): applications, environment controls with the
  execution node, allowlists, settings, the deployments of every application,
  and marking a run stuck by hand.
- **Owners** (O1-O4): environments, job templates with their history,
  variables at every level, and versions.

It has two halves, each with its backend and its screens:
- **6a, administrators:** first, because the owner screens need applications
  and environment controls to exist.
- **6b, owners.**

Profile and notification settings (U2, `PUT /me`) wait for mail (S5).

Built and tried on t01 (2026-11-15): the backend of both halves, with
`testIteration6a.py` and `testIteration6.py`. The screens (F7 to F10) were
built against the frontend's mock (`lwdeploy-frontend/PLAN-ADMIN.md`); their
build is in `LWWAdmin`, with the route folders `admin/...` and `template`, and
was tried on t01 as an administrator and as an owner (2026-11-16).

## Decisions

| Subject | Decision |
|---|---|
| Modules for changes | One module per table, with the operation as a constant that LWW sets per path, as `CTFM008` does for CTF and `LWDM511` for the deployment actions: `OPCODE` C create, R read, U update, D delete, and a letter of its own for anything else. Number `LWDM0nn`, nn the table. Create stays in `LWDM405` for versions, which the CI pipeline already calls |
| Admin lists | `GET /admin/applications` and `GET /admin/deployments` reuse `LWDM204` and `LWDM211` with a constant `ADMINVIEW` Y, as `CTFM314` does: every row, after the administrator check. No second module with the same cursor |
| Administrator check | Two layers. First RACF: only the admin group may use transaction `LWDA`, so LWW refuses anyone else with 403 before a module runs, without LWD's envelope (seen on t01). Then `R098-REQUIRE-ADMIN` in `LWDCTXP` (`R095-CHECK-ADMIN`, QUERY SECURITY on `ADMINRES`) in every `/admin` module, `08 50`, for a userid that has `LWDA` but no READ on `ADMINRES` |
| Administrators on owner paths | Refused (`08 50`) unless they are in the owner group too (04-api.md: administrators read everything, but change only through `/admin`) |
| Settings | `PUT /admin/refTables/SETTINGS?tabKey=` only for the timing and job keys: `APPRHRS`, `JOBMINS`, `OUTDAYS`, `OUTLINES`, `GRPMINS`, `JOBCLASS`, `MSGCLASS`, `MAILFROM`, `MAILURL`. The security and location keys (`ADMINRES`, `GRPPRFX`, `SUBMUSR`, `SUBMTXN`, `SCHEDUSR`, `JOBPRFX`, `LOADLIB`, `EXECLIB`, `LWDURL`, `LWDPORT`, `LWDPATH`, `LWWAPPL`, `LWDRING`) and `LASTTICK` give `08 50`: they come from `envs/<env>.yaml` through `DDL/SETTINGS`. No settings are created or deleted through the API |
| Execution node | `execNode` joins the environment controls (request of `PUT /admin/environmentControls/{envID}` and every environment response). Iteration 4 left it to DB2 until now |
| Mark a run stuck (A4) | New in the contract: `POST /admin/stuckRuns/{runID}`. Only for a run that is S: result T and status F, and the job and deployment F, exactly as `LWDM930` does after `JOBMINS`. A run that isn't S any more is answered `08 53`; nothing changes |
| New environment | Approval on, N = 1, no approver group, no deploy userid (O1). It can't be deployed to (`08 59`) until an administrator has set its controls (A2) |
| Deleting | An application or environment with deployments: `08 53`. A version once requested: `08 53`, retire it instead. A template gets status D; its revisions stay, so frozen JCL can still be traced to a revision. Deleting an application deletes its environments, versions, variables and templates with it; deleting an environment or version deletes its variables |
| Template JCL | Saved as a whole new revision with `POST /templateJcl/{templateID}` (multipart, as 04-api.md describes). Refused with `08 56`, naming the first line: a JOB statement, `USER=` or `PASSWORD=`, a JES2 (`/*JOBPARM`, `/*ROUTE`, `/*XEQ`, `/*OUTPUT`, `/*PRIORITY`, `/*NETACCT`, `/*NOTIFY`, `/*SETUP`, `/*SIGNON`, `/*XMIT`) or JES3 (`//*` followed by a JES3 keyword, such as `//*MAIN`) statement, a line over 80 characters, more than 300 lines. Warnings, not refusals (`warningCount`, the first in `infoMessage`): a `${NAME}` that is defined at no level yet, a statement that passes column 71 |
| Variables | `GET /variables` lists one level: application (`appID` only), environment (`envID`) or version (`versionID`). Names `A-Z 0-9 _`, starting with a letter, at most 16, never starting with `LWD` (the built-ins). Values aren't secret: the UI says so next to every value field |
| Versions | `PUT` and `DELETE` only while `isUsed` is N (`08 53` otherwise); retire any time. A retired version stays in the inventory and history |
| Limits | 20 environments and 20 active templates per application (`08 53` for the 21st), as `GET /environments` and `GET /templates` never page |

## 6a: administrators

### Backend

| Method and path | Wrapper | Module | Op | Use case |
|---|---|---|---|---|
| GET `/admin/applications` | `LWDC204` | `LWDM204` | `ADMINVIEW` Y | A1, A4 |
| POST `/admin/applications` | `LWDC004` | `LWDM004` | C | A1 |
| GET `/admin/applications/{appID}` | `LWDC004` | `LWDM004` | R | A1 |
| PUT `/admin/applications/{appID}` | `LWDC004` | `LWDM004` | U | A1 |
| DELETE `/admin/applications/{appID}` | `LWDC004` | `LWDM004` | D | A1 |
| PUT `/admin/environmentControls/{envID}` | `LWDC006` | `LWDM006` | K | A2 |
| GET `/environments/{envID}` | `LWDC006` | `LWDM006` | R | A2, M2, O1 |
| GET `/admin/refTables` | `LWDC201` | `LWDM201` | | A3, A5 |
| POST `/admin/refTables` | `LWDC001` | `LWDM001` | C | A3 |
| PUT `/admin/refTables/{tableID}` | `LWDC001` | `LWDM001` | U | A3, A5 |
| DELETE `/admin/refTables/{tableID}` | `LWDC001` | `LWDM001` | D | A3 |
| GET `/admin/deployments` | `LWDC211` | `LWDM211` | `ADMINVIEW` Y | A4 |
| POST `/admin/stuckRuns/{runID}` | `LWDC514` | `LWDM514` | | A4 |

Paths that share a module share its wrapper too: `genlww.py` makes one
`LWDCnnn` per module, and the suffix letter (`sfx`) only keeps the names of
their LWW steps apart, as for `LWDM511`.

Rules per module:

- **`LWDM004` applications:**
  - `appCode` unique, `A-Z 0-9`, at most 8 (`08 11` when taken).
  - Both groups must be in the `RACFGRP` allowlist (`08 02`).
  - Delete with deployments: `08 53`. Without deployments it deletes the
    application's environments, versions, variables, templates, revisions and
    lines in one unit of work.
- **`LWDM006` K, environment controls:**
  - `deployUser` in `DEPLUSER`.
  - `approverGroup` and `deployerGroup` in `RACFGRP`.
  - Approval Y needs an approver group and N of at least 1 (`08 02`).
    Approval N stores N as 0 (the contract's "0 = none"); the approver group
    may stay.
  - `execNode`: empty, or a JES2 node name of 1 to 8 characters.
  - Deployments already requested keep what they were requested with (A2).
- **`LWDM006` R, one environment:** with its controls, for whoever may see the
  application (`04 01` otherwise), and the same `canDeploy` and `canApprove`
  as `LWDM206`. The admin screen of an application reads each environment
  with it, because `GET /environments` has no controls. Moved here from 6b
  for that; 6b only adds C, U and D.
- **`LWDM201`, `LWDM001` reference tables:**
  - **`RACFGRP` and `DEPLUSER`:** keys in RACF form (`08 02`), once per list (`08 11`), values are descriptions of at most 255. Delete refuses an entry still used by an application or environment (`08 53`, naming one, for instance "LWDHR is still used: access group of HRAP").
  - Creating or deleting a `SETTINGS` entry, or changing one not in the list below: `08 50`.
  - **`SETTINGS`:** update only, for the keys of the decision above. Values are checked:
    - `APPRHRS` 1-720
    - `JOBMINS` 5-1440
    - `OUTDAYS` 1-3650
    - `OUTLINES` 1000-500000
    - `GRPMINS` 1-1440
    - `JOBCLASS`, `MSGCLASS`: one character, A-Z or 0-9 (upper-cased)
    - `MAILFROM`: an email address; `MAILURL`: a URL starting with `http://` or `https://`; both at most 255
- **`LWDM211` with `ADMINVIEW`:** `appID_filter` instead of `appID`, and no rule about the own requests. Same cursor, with the visibility condition switched off.
- **`LWDM514` stuck run:** the run must be S (`08 53` otherwise; `08 31` for an unknown run). It locks the run row first, so a result step reporting at the same moment either comes first (`08 53`) or waits. It then does what `LWDM930`'s stuck branch does, with the section both already share, `R660-RUN-FAILED` in `LWDDEPP`: the run gets F and T with the message "Marked stuck by <userid>", the job F, the deployment F, and event F with the same comment, by the administrator. Answer: `runID`, `runStatus`, `jobResult`, `deplID`, `deplStatus`. The output collector still collects the run's output, as for the scheduler's stuck runs: `LWDM940` lists E and F runs.

Contract changes in `genoas.py`:
- `execNode` in the environment schemas and the controls request
- the new path `/admin/stuckRuns/{runID}`
- `ADMINVIEW` is a constant, as `deplAction` is, not a field of the contract

### Screens

An admin section under `/lwdeploy/admin`, in a lazy chunk of its own, as
ctflww-frontend does it. The top bar gets "Admin" for administrators. The
route folders under `admin/` run under `LWDU` with the login redirect, as the
other routes: they serve only `index.html`, and the admin API paths have
`LWDA`.

| Route | Screen | Use cases | API calls |
|---|---|---|---|
| `/lwdeploy/admin` | Applications: all of them, with their groups; create | A1 | `GET /admin/applications`, `POST /admin/applications` |
| `/lwdeploy/admin/app?appID=` | One application: code, name, description, groups; delete. Its environments with their controls, each editable | A1, A2 | `GET /admin/applications/{appID}`, `PUT`, `DELETE`, `GET /environments?appID=`, `GET /environments/{envID}`, `PUT /admin/environmentControls/{envID}` |
| `/lwdeploy/admin/lists` | Allowlists: RACF groups and deploy userids, add and remove | A3 | `GET`, `POST`, `DELETE /admin/refTables` |
| `/lwdeploy/admin/settings` | Settings: the editable ones as a form; the others read-only, with where they come from | A5 | `GET /admin/refTables?tableID=SETTINGS`, `PUT /admin/refTables/SETTINGS?tabKey=` |
| `/lwdeploy/admin/deployments` | Deployments of every application, with filters | A4 | `GET /admin/deployments` |

Every list and form follows the patterns of iteration 5.
- **Group and userid fields** are choices from the allowlists, not free text,
  so `08 02` is rare.
- **Environment controls:** the form shows the A2 warning that the approver
  group needs more than N members besides the requester.
- **Mark stuck:** on the existing runs page (`/run`), an administrator sees
  "Mark stuck" next to a run that is S. It asks for confirmation and explains
  when to use it: the job has ended in JES, but its result step didn't
  report.

## 6b: owners

### Backend

| Method and path | Wrapper | Module | Op | Use case |
|---|---|---|---|---|
| POST `/environments` | `LWDC006C` | `LWDM006` | C | O1 |
| PUT `/environments/{envID}` | `LWDC006U` | `LWDM006` | U | O1 |
| DELETE `/environments/{envID}` | `LWDC006D` | `LWDM006` | D | O1 |
| GET `/versions/{versionID}` | `LWDC005R` | `LWDM005` | R | M2, O4 |
| PUT `/versions/{versionID}` | `LWDC005U` | `LWDM005` | U | O4 |
| DELETE `/versions/{versionID}` | `LWDC005D` | `LWDM005` | D | O4 |
| POST `/versionRetirements/{versionID}` | `LWDC005T` | `LWDM005` | T | O4 |
| GET `/variables` | `LWDC207` | `LWDM207` | | O1, O3, O4 |
| POST `/variables` | `LWDC007C` | `LWDM007` | C | O1, O3, O4 |
| PUT `/variables/{varID}` | `LWDC007U` | `LWDM007` | U | O1, O3, O4 |
| DELETE `/variables/{varID}` | `LWDC007D` | `LWDM007` | D | O1, O3, O4 |
| GET `/templates` | `LWDC208` | `LWDM208` | | O2 |
| POST `/templates` | `LWDC008C` | `LWDM008` | C | O2 |
| GET `/templates/{templateID}` | `LWDC008R` | `LWDM008` | R | O2 |
| PUT `/templates/{templateID}` | `LWDC008U` | `LWDM008` | U | O2 |
| DELETE `/templates/{templateID}` | `LWDC008D` | `LWDM008` | D | O2 |
| GET `/templateRevisions` | `LWDC209` | `LWDM209` | | O2 |
| GET `/templateJcl/{templateID}` | `LWDC310` | `LWDM310` | | O2 |
| POST `/templateJcl/{templateID}` | `LWDC410` | `LWDM410` | | O2 |

All `user` paths, transaction `LWDU`.
- **Who may read:** members, owners and approvers, as for the other reads.
- **Who may change:** owners only (`08 50`).

Rules per module:

- **`LWDM006` C, U, D environments** (R is in 6a):
  - `envCode` unique within the application (`08 11`).
  - C gives the protected defaults of the decision above.
  - U changes code, name, description, order and promotion gate, never the
    controls.
  - D refuses an environment with deployments (`08 53`).
- **`LWDM005` R, U, D, T versions:** the checks of the decision above. U keeps
  `versionName` unique within the application.
- **`LWDM207`, `LWDM007` variables:**
  - The level comes from which of `envID` and `versionID` are set; both set is
    `08 02`.
  - The environment or version must belong to the application (`08 13`).
  - Unique per level (`08 11`), and the name rules of the decision above.
- **`LWDM208`, `LWDM008` templates:**
  - C makes the template without JCL (revision 0). A deployment refuses an
    application with such a template (`08 59`, as today).
  - U changes name, order and highest RC (0 to 4095); D sets status D.
  - A deleted template stays readable (R, revisions, JCL), so frozen JCL can
    be traced to it; it can't be changed any more (`08 53`).
  - The list holds the active templates in order.
- **`LWDM209` revisions:** newest first, `revision_since` for the next page.
- **`LWDM310` template JCL:** one revision (0 = current), base64 as for frozen
  JCL (`LWDU981` E). A template without JCL answers revision 0 with no lines;
  a revision that doesn't exist is `04 01`.
- **`LWDM410` save JCL:**
  - Gets the form fields `jcl` and `changeNote` from its wrapper `LWDC410`,
    which reads them with `WEB READ FORMFIELD`: the DB2 modules are compiled
    without the CICS translator (`OPTFILE/DB2.opt`).
  - Decodes `jcl` with `LWDU981` D, converts from UTF-8, drops CR, and splits
    at LF; a last LF makes no extra empty line. A missing field, bad base64
    or bad UTF-8: `08 58`.
  - Checks the lines as the decision above says, and refuses empty JCL
    (`08 56`). `USER=` and `PASSWORD=` count only on statements (`//` not
    followed by `*`), not in comments or in-stream data.
  - Then inserts TEMPLATEREVS and TEMPLATELINES and sets `CURRENTREV`, in one
    unit of work.
  - Answers the new revision with `warningCount`, the first warning in
    `infoMessage`.

### Screens

Owner features join the application page of iteration 5 rather than a section
of their own. Changing shows only where `isOwner` is Y; the variables of every
level and the templates can be read by every member, so they show for
everyone:

| Where | What | Use cases |
|---|---|---|
| Environments tab | Add; edit name, description, order (up and down), gate; delete; its variables | O1 |
| Versions tab | Register (as CI does), edit while unused, retire, delete while unused; its variables | O4 |
| New tab: Templates | The templates in order with highest RC and current revision; add, rename, reorder, delete | O2 |
| New tab: Variables | The application's variables; add, change, delete | O3 |
| `/lwdeploy/template?templateID=` | One template: the current JCL in an editor (a monospace textarea with line numbers and an 80-column ruler), save with a change note, the warnings of the save; the revisions, and two revisions side by side with their differences. `&revision=` shows an older revision read-only; the frozen JCL page links there | O2 |

Moving an environment up or down swaps the order of two neighbours with two
`PUT /environments/{envID}`: there is no path to reorder. Editing reads the
environment first, as `PUT` replaces every field and the list has no
description.

- **Variables at the three levels** use one component. Every value field
  repeats that values are visible to every member and must never hold a
  password.
- **Comparing revisions:** a line diff written in the app (longest common
  subsequence, at most 300 lines a side, so no library is needed).
- **Frozen JCL** and the template revision a job was frozen from are already
  linked on the JCL page of iteration 5.

A new route folder `template` with its `.name` file, under `LWDU` with the
login redirect, as the other routes. The admin routes are folders under `admin`.

## Mocks and tests

As in iteration 5: every new operation goes into the frontend's mock first,
with the checks and reason codes above, and the screens are built and tested
against it. `PLAN-ADMIN.md` in the frontend gets the steps:

| Step | Content |
|---|---|
| F7 | Admin section: applications, application with environment controls (6a) |
| F8 | Allowlists, settings, deployments of every application, mark stuck (6a) |
| F9 | Owner features on the application page: environments, versions, variables (6b) |
| F10 | Templates: list, editor, save with warnings, revisions, compare (6b) |

The backend modules of 6a can be built while F9 and F10 are under way.
`python/testIteration6a.py` tests 6a on its own (see "Built: 6a backend").
`python/testIteration6.py` tests both halves without the UI:
1. An administrator creates an application with groups from the allowlist.
2. An owner adds three environments.
3. The administrator sets their controls.
4. The owner adds two templates with JCL, a refused save (a JOB statement),
   and application and environment variables.
5. A deployment of a new version succeeds.
6. The test application is deleted again, which fails while it has
   deployments, so it is cancelled first and left in place: the script prints
   what it leaves.

## Built: 6a backend

New modules, with their wrappers, copybooks and link-edit decks from
`genlww.py`:

| Module | Paths | Notes |
|---|---|---|
| `LWDM004` | `/admin/applications/...` C, R, U, D | Delete: children first (template lines, revisions, templates, variables, environments, versions), as the foreign keys are `ON DELETE RESTRICT` |
| `LWDM006` | `GET /environments/{envID}` R, `PUT /admin/environmentControls/{envID}` K | Its IO area already holds the fields of C, U and D, so 6b doesn't change `LLWDM006`. Other OPCODEs are `08 01` until 6b |
| `LWDM201` | `GET /admin/refTables` | |
| `LWDM001` | `POST`, `PUT`, `DELETE /admin/refTables` | Settings checked as above; values without trailing blanks |
| `LWDM514` | `POST /admin/stuckRuns/{runID}` | |

Changed:
- **`LWDM204`, `LWDM211`:** `ADMINVIEW`, a new field at the end of their
  scalars; `LLWDM204`'s list also holds the two groups. Both need building
  again. On the user paths LWW never sets `ADMINVIEW`, so it stays binary
  zeros and the user view is what they get.
- **`LWDCTXP`, `LWDCTXW`:** `R098-REQUIRE-ADMIN` (`08 50`) and `R099-IN-LIST`
  (is a key in `RACFGRP` or `DEPLUSER`), for every admin module.
- **`genlww.py`:** paths that share a module say so:
  - `io` lists the fields of the shared IO area in order;
  - `lmap` lists the list fields that path answers;
  - `created` lets the shared wrapper answer 201 for one OPCODE;
  - a fourth element of an input maps it onto another field (`appID_filter`
    onto `APPID`);
  - a path without an ID in it gets its constant with the body or the query
    parameters.

  It checks that such paths produce the same copybook and the same wrapper.
- **`genoas.py`:** `execNode` in the environment schemas and the controls
  request, and `POST /admin/stuckRuns/{runID}`.
- **`LWWAdmin`:** the placeholder `API/v1/admin/stuckRuns` under `LWDA`.

## Built: 6b backend

New modules, with their wrappers, copybooks and link-edit decks from
`genlww.py`:

| Module | Paths | Notes |
|---|---|---|
| `LWDM006` | C, U, D added to R and K | `LLWDM006` unchanged since 6a |
| `LWDM005` | `GET`, `PUT`, `DELETE /versions/{versionID}`, `POST /versionRetirements/{versionID}` | U with the checks of `LWDM405` |
| `LWDM207` | `GET /variables` | One level, by `VARID` |
| `LWDM007` | `POST`, `PUT`, `DELETE /variables` | |
| `LWDM208` | `GET /templates` | Active ones in order |
| `LWDM008` | `/templates` C, R, U, D | |
| `LWDM209` | `GET /templateRevisions` | Newest first |
| `LWDM310` | `GET /templateJcl/{templateID}` | No LF after the last line, unlike frozen JCL from `LWDM313` |
| `LWDM410` | `POST /templateJcl/{templateID}` | The checks of the decision "Template JCL" |

Changed and decided while building:
- **`LWDCTXP`:** `R106-REQUIRE-OWNER` (`08 50`), after `R105`, in every
  module that changes something for owners.
- **`genlww.py`:** `form` makes the wrapper read the form fields `jcl`
  (into `JCL`, its length in `JCLLENGTH`, a field outside the contract) and
  `changeNote` before it calls the module. `JCLLENGTH` 0 means the field is
  missing; more than the length of `JCL` means it was too long.
- **`sortOrder` 0 in a PUT keeps the order** (`LWDM006` U, `LWDM008` U): the
  IO area can't tell 0 from a field that wasn't sent. The UI never sends 0
  when it swaps two neighbours, and the mock does the same.
- **`LWDM410`** keeps no trailing blanks on a line; `USER=` and `PASSWORD=`
  count at the start of a parameter (after a blank or a comma) on a
  statement.
- **`python/testIteration6.py`** walks through the six steps of "Mocks and
  tests" above. It leaves the test application in place, as it then has a
  deployment, and prints how to remove it.

## Setting it up on t01

1. **Build and deploy:** `. ./setenv`, `build`, `python python/deploy.py`, with
   the new modules of the half being delivered. For 6a: `LWDC001`, `LWDM001`,
   `LWDC004`, `LWDM004`, `LWDC006`, `LWDM006`, `LWDC201`, `LWDM201`,
   `LWDC514`, `LWDM514`, and again `LWDC204`, `LWDM204`, `LWDC211`, `LWDM211`
   (their copybooks changed). For 6b: `LWDC005`, `LWDM005`, `LWDC006` and
   `LWDM006` again, `LWDC007`, `LWDM007`, `LWDC008`, `LWDM008`, `LWDC207`,
   `LWDM207`, `LWDC208`, `LWDM208`, `LWDC209`, `LWDM209`, `LWDC310`,
   `LWDM310`, `LWDC410`, `LWDM410`. `LWDCTXP` changed, so every module that
   is built again gets `R106-REQUIRE-OWNER`; the others don't need it.
2. **CICS:** install the new programs, `NEWCOPY` the four changed ones.
3. **LWW:**
   - one new placeholder: `admin/stuckRuns` under `LWDA`; all the others
     exist since iteration 1
   - specs to `remoteOASDir`, `processYAML.py`, `uploadLWW.py`
4. **RACF:** nothing new. Administrators already have `LWDA`, and owners
   `LWDU`.

## To check on the first run

- **A constant without an ID in the path:** CTF only ever sets one with the
  ID from the path. `POST /admin/applications` and `POST /admin/refTables`
  get `OPCODE` with the body, `GET /admin/applications` and
  `GET /admin/deployments` get `ADMINVIEW` with the query parameters, even
  when no parameter is sent. If LWW skips that mapping, the admin list paths
  answer what the user paths would (never more), and the two POSTs answer
  `08 01` Invalid OPCODE.
- **A text ID in the path:** `PUT` and `DELETE /admin/refTables/{tableID}`
  extract `RACFGRP` from the path into a `PIC N(8)` field; every other LWD ID
  is a number.

- **`WEB READ FORMFIELD`** of a multipart body through LWW: 04-api.md says
  CICS parses it, but no LWD path has used it yet. `LWDC410` reads it after
  LWW's steps, which don't touch the body (no `ParseRequestJSON`).
- **The code page of `changeNote`:** `WEB READ FORMFIELD` converts the form
  data to the region's code page (037 here), so a character outside 037 in a
  change note doesn't survive. `jcl` is base64, which 037 holds exactly.
- **The 32 KB cap** on a template of 300 full lines, as base64 (04-api.md).
- **Deleting an application:** the cascade is the biggest unit of work in LWD
  so far. Check the locks with a realistic number of template revisions.

## Not built yet

- **Mail (S5)** and the profile (U2, `PUT /me`), together:
  [11-iteration-7.md](11-iteration-7.md).
- **Multi-application releases** and the rest of "Out of scope for v1" in
  02-use-cases.md.
- **From iteration 4:**
  - `SYSAFF` within a JES2 MAS
  - removing `LWDM915` and `MODE-BATCH` of `LWDM920`
