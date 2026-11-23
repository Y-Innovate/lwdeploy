# Iteration 5: the web UI for members, deployers and approvers

Iterations 1 to 4 built the deployment itself:
- request, approval, scheduling, retry and continue
- job output in DB2
- results over REST

All of it works on t01, but only through Python scripts. This iteration adds
the web UI for the people who use LWD every day:
- **Members** see their applications, what is deployed where, the history and
  the job output (M1-M4).
- **Deployers** request a deployment, follow it, and cancel, retry or
  continue it (D1-D4).
- **Approvers** see what waits for them, read the frozen JCL, and approve or
  reject (AP1, AP2).

Admin and owner screens are not in it. They come in iteration 6, together with
the admin API and the owner API they need (A1-A5, O1-O4). Until then that work
is done in DB2, as before.

The UI is a React app in its own repository, `lwdeploy-frontend`, built the way
ctflww-frontend is. LWW serves it under `/lwdeploy/`, next to the API. The backend
gets the few pieces the screens need that aren't built yet.

Built and tried on t01 (2026-11-15), with the public transaction `LWDP` and
its plan `LWDT01P` that came up while setting it up.

## Decisions

| Subject | Decision |
|---|---|
| Repository | `lwdeploy-frontend`. `npm run build` writes into `lwdeploy/LWWAdmin/`, and `python/uploadLWW.py` puts it on LWW, as for CTF |
| Stack | As ctflww-frontend: React, React Router, Vite, Tailwind, vite-plugin-mock-dev-server, Vitest with Testing Library, ESLint, Tabler icons. No new dependencies. `docs/stack-react-lww.md` is copied, with `/ctf` replaced by `/lwdeploy` |
| Paths | App `/lwdeploy/`, API `/lwdeploy/API/v1` |
| Routes | One folder per route, IDs in the query string (`/lwdeploy/deployment?deplID=52`), because LWW has no SPA fallback. Every route except `/lwdeploy/login` requires a session |
| Sign-in | The React page `/lwdeploy/login`: a form that posts userid and passphrase to `process_login.html`, and a button for Entra (`redirect_to_sso_login.html`). Unlike CTF, both are for everyone (decision 8 in [02-use-cases.md](02-use-cases.md)) |
| Sign-out | LWW's `logout.html` with pre-exec `LWWADPLO`, as CTF has since 2026-11-14 |
| Who may do what | The backend decides. The UI shows buttons from the `can*` and `is*` flags and shows `infoMessage` when the backend refuses |
| Updating | Polling: a running deployment every 5 seconds, everything else when the page is opened. No email yet (S5) |
| Codes | Statuses are translated to words in `src/lib/codes.js`, never shown raw |
| Timestamps | Shown as DB2 sends them, in z/OS local time, cut to the minute. `startAfter` from the browser is sent in the same format. This assumes the browser and z/OS are in the same time zone (to check) |

## Backend: what is added

| Method and path | Wrapper | Module | Use case | Why |
|---|---|---|---|---|
| GET `/deployments` | `LWDC211` | `LWDM211` | M3 | The history of an application, and "my requests" on the start page |
| GET `/applications/{appID}` | `LWDC304` | `LWDM304` | M1 | An application page opened from a link, without paging through `GET /applications` |

Both are in the contract already. They only need entries in `genlww.py`
(which generates `LLWDM211`, `LLWDM304`, the wrappers, the link-edit decks and
the LWW steps) and the COBOL modules. The LWW placeholders `applications` and
`deployments` exist already and also cover the paths below them. Transaction
`LWDU`.

**`GET /deployments` (`LWDM211`):** newest first, 20 per page,
`deplID_since` for the next page. The filters `envID_filter`,
`versionID_filter`, `deplStatus_filter` and `requestedBy_filter` are optional.
Which rows a user sees:

| Request | Rows |
|---|---|
| `appID` given, member, owner or administrator | All deployments of the application |
| `appID` given, only approver | Only the deployments this user decided on (an APPROVALS row). Those still waiting come from `GET /approvalRequests` |
| `appID` given, no role | `04 01` |
| `appID` 0 with `requestedBy_filter` set to the user's own userid | The user's own requests, in all applications |
| `appID` 0 otherwise | `08 01`. Static SQL can't easily filter on "every application I have a role in", which is a FACILITY check per group. An admin sees everything in `GET /admin/deployments` (iteration 6) |

These rules narrow the contract's description "0 = all of mine". The
description in `genoas.py` is changed to match. A `deplStatus_filter` that
isn't a status gives `08 03`.

**`GET /applications/{appID}` (`LWDM304`):** the application with
`isMember`, `isOwner` and `isApprover`, for a member, owner, approver or
administrator, as `R100-APP-ROLES` decides; `04 01` for anyone else.

**`STARTAFTER` is never empty:** LWDM411 stores the request time when the
requester asked for "as soon as possible". The UI therefore shows a requested
start only when it is a later minute than the request.

**Also in the backend:**
- `LWWAdmin/logout.html` with its `.logout.html` (pre-exec `LWWADPLO`), copied
  from CTF.
- `.name` files for the route folders, each with `defaultWebpageId` of
  index.html, `loginRedirectWebpageId` of `redirect_to_login.html` and
  `defaultTran` `LWDU`, as the `/lwdeploy` folder itself has, with the same
  login redirect (`uploadLWW.py`).
  Only `login` runs under the new public transaction `LWDP`, as `index.html`
  and `assets/` do: they must load before sign-in, and the CICS default userid
  has no access to `LWDU`. `LWBL` stays for LWW's own sign-in pages.
- **`LWDP`, LWD's public transaction** (`CICSTXN_PUBLIC`), as `CTFP` is for
  CTF:
  - `JCL/CICSCSD`: the transaction (`DFHWBA`) and its DB2ENTRY, because LWW
    serves files from DB2
  - `JCL/BINDPLAN`: its plan `DB2PLAN_PUBLIC` (`LWDT01P`) with only LWW's own
    packages; LWD has no public paths
  - `JCL/RACF`: `GCICSTRN LWDPUB`, `DFHDB2.AUTHTYPE.LWDP` and EXECUTE on
    `LWDT01P` for the CICS default userid, `USERGROUP` and `ADMINGROUP`
    (signed-in users load the same files). The default userid gets nothing
    on `LWDT01`, the plan with LWD's modules. They live in the frontend's `public/` and arrive
  with the build.
- [04-api.md](04-api.md): the access rules of `GET /deployments`.

Already built and used as they are: `GET /me`, `GET /applications`,
`GET /environments`, `GET /versions`, `POST /deployments`,
`GET /deployments/{deplID}`, the three actions, `GET /deploymentJobs`,
`GET /deploymentJcl/{deplID}`, `GET /deploymentEvents`,
`GET /approvalRequests`, `GET /approvals`, `POST /approvals`, `GET /jobRuns`,
`GET /jobSteps`, `GET /spoolFiles` and `GET /spoolText/{runID}`.

## Screens

| Route | Screen | Use cases | API calls |
|---|---|---|---|
| `/lwdeploy/login` | Sign-in form and Entra button | U1 | Posts to `process_login.html`, or goes to `redirect_to_sso_login.html` |
| `/lwdeploy/` | Start page: my applications, the approvals waiting for me, my latest requests | U1, M1, AP1 | `GET /me`, `GET /applications`, `GET /deployments?appID=0&requestedBy_filter=<me>` |
| `/lwdeploy/app?appID=` | Application, with three tabs: environments, versions, deployments | M1, M2, M3 | `GET /applications/{appID}`, `GET /environments?appID=`, `GET /versions?appID=`, `GET /deployments?appID=` with filters |
| `/lwdeploy/deploy?appID=&envID=` | Request a deployment: version, start time, note | D1 | `GET /environments?appID=`, `GET /versions?appID=&versionStatus_filter=A`, `POST /deployments` |
| `/lwdeploy/deployment?deplID=` | Deployment: status, jobs, approvals, history, actions | M3, D2, D3, D4, AP2 | `GET /deployments/{deplID}`, `GET /deploymentJobs`, `GET /approvals`, `GET /deploymentEvents`, `POST /cancellations`, `/retries`, `/continuations`, `POST /approvals` |
| `/lwdeploy/jcl?deplID=&jobNo=` | Frozen JCL of one job | M3, AP2 | `GET /deploymentJcl/{deplID}?jobNo=` |
| `/lwdeploy/run?deplID=&jobNo=&runID=` | The runs of a job, the steps of a run and their return codes, its spool files | M3, M4 | `GET /jobRuns`, `GET /jobSteps`, `GET /spoolFiles` |
| `/lwdeploy/output?runID=&fileNo=` | One spool file, page by page; `deplID` and `jobNo` may be added for the link back to the run | M4 | `GET /spoolText/{runID}?fileNo=&lineNum_since=` |
| `/lwdeploy/approvals` | The deployments waiting for my approval, oldest first | AP1 | `GET /approvalRequests` |

The top bar has links to the start page and to the approvals, with the number
from `approvalsWaiting` in `GET /me`. It also shows the userid and the sign-out
button. An admin sees the same screens as anyone else. The admin screens come
in iteration 6.

### Start page (`/lwdeploy/`)

- **Applications:** a card per application, showing its code and name and the
  user's roles (member, owner, approver).
- **Approvals:** "N approvals wait for you" with a link to `/lwdeploy/approvals`,
  only when N > 0.
- **My requests:** the user's last 20, with application, environment,
  version, status and date.
- **No applications:** a user without a role and not an admin gets the U1
  text: ask an administrator for access.

### Application (`/lwdeploy/app`)

- **Environments** (M2):
  - One row per environment, in order: the version deployed there and when.
  - A warning when `envState` says the environment may be half deployed.
  - A link to the active deployment, if there is one.
  - Labels for approval required (N approvers) and the promotion gate.
  - A **Deploy** button when `canDeploy` is Y, which goes to
    `/lwdeploy/deploy?appID=&envID=`.
- **Versions:** name, location, status and date, newest first, with "load
  more". Retired versions are hidden unless the user ticks "show retired".
- **Deployments** (M3): the list from `GET /deployments`, with filters on
  environment, version, status and "only mine", and "load more".

### Request a deployment (`/lwdeploy/deploy`)

- **Environment:** preset, and can still be changed to another environment
  where `canDeploy` is Y.
- **Version:** a choice of the active versions, newest first. The page shows
  what is in the previous environment, so the user can see whether the
  promotion gate will pass. The backend still checks it.
- **Start:** now, or at a date and time.
- **Note:** optional.
- **After submitting:** 201 goes to `/lwdeploy/deployment?deplID=`, which says
  whether the deployment waits for approval (W) or is queued (Q). On a refusal
  the page shows `infoMessage`:
  - `08 54` the gate didn't pass
  - `08 57` a variable has no value
  - `08 59` the environment isn't ready
  - `08 50` the user isn't a deployer

### Deployment (`/lwdeploy/deployment`)

- **Header:** application, environment, version and location, status in
  words, requester, note, the requested start, started and ended.
- **Jobs:** one row per job: title, highest RC, job status, the last run's
  result, RC or abend, and the skip reason. Links go to the frozen JCL
  (`/lwdeploy/jcl`) and the runs and output (`/lwdeploy/run`).
- **Approval:** "N of M approvals", the decisions with comments, and
  **Approve** and **Reject** when `canApprove` is Y. Rejecting needs a
  comment.
- **History:** the events, oldest first.
- **Actions:**
  - **Cancel** when `canCancel` is Y, with an optional reason.
  - **Retry** and **Continue** when `canRetry` is Y. Continue needs the reason
    for skipping the job.
  - Each asks for confirmation first.
  - D3's limit, that a job that is submitted can't be cancelled, shows up as a
    disabled Cancel with that explanation, and as the `08 53` message if the
    user was faster than the page.
- **Polling:** every 5 seconds while the status is Q or U, and every 30
  seconds while it is W. It stops on a final status (J, E, S, F, C) and while
  the tab is hidden.

### Output (`/lwdeploy/run`, `/lwdeploy/output`)

- **Runs:** the runs of the job, newest first. For each: job name, JES job ID,
  submitted, ended, result and `jobMessage`.
- **Steps:** step name, proc step, program, RC or abend, and "flushed", for the
  chosen run.
- **Spool files:** DD name and step, number of lines, and "truncated". Output
  status W (waiting) says the collector hasn't been yet, and the page polls
  every 30 seconds. N (none found) and P (purged) are explained in words; the
  return codes stay visible.
- **Text:** the text of one spool file, decoded from base64 as UTF-8, in a
  monospace block. "Next 300 lines" uses `moreLines` and `lineNum_since`.

### Approvals (`/lwdeploy/approvals`)

- **List:** the deployments waiting for the user, oldest first: application,
  environment, version, requester, requested, start after, and N of M.
- **Rows:** each row goes to the deployment page, where the user reads the
  JCL and decides. The page doesn't let the user decide from the list,
  because AP2 needs the JCL to have been seen.

## Frontend repository

`lwdeploy-frontend` starts as a copy of ctflww-frontend's structure. It has no
CTF screens.

| File | Content |
|---|---|
| `CLAUDE.md` | This app, base path `/lwdeploy`, backend repo `lwdeploy`, the audiences (members, deployers, approvers; admins and owners later) |
| `docs/stack-react-lww.md` | The stack rules, with `/lwdeploy`; the roles and `GET /me` fields of LWD instead of player and admin |
| `PLAN.md` | The routes, the LWW folders and the steps with checkboxes, as below |
| `openapi/lwdeploy.yaml` | Copy of `lwdeploy/openapi/lwd_1.0.0.yaml` |
| `mock/` | An in-memory DB2 with a seed matching t01's DEMO application: DEV, TST and PRD (PRD with 2 approvers), versions `V1.0.0` and `V1.0.1-BAD`, and two jobs. A mock clock moves a deployment through Q, U and S, or F for the bad version, so the polling can be seen working without CICS |
| `scripts/` | `clean-lww.js` and `lww-dir.js`, with `../lwdeploy/LWWAdmin` |
| `public/` | The LWW pages (`process_login.html`, `redirect_to_login.html`, `redirect_to_sso_login.html`, `auth`, `logout.html`) and a folder with `.name` per route |

Reused from CTF where it fits:
- the API client, which trims, treats `null` and `""` alike, and does
  sign-in on 401
- `usePolling` and `usePagedList`
- `SessionContext`
- `ErrorBanner` and `ConfirmButton`
- the timestamp helpers

Each one is copied and adapted, not shared as a package.

### Steps

| Step | Content |
|---|---|
| F1 | Scaffold, the API client, the session and the sign-in page, the top bar, the mock server with the seed. Lint and tests pass |
| F2 | Start page and application page (M1, M2, M3 list) |
| F3 | Request a deployment and the deployment page with polling and the actions (D1-D4) |
| F4 | Approvals list, approving and rejecting, frozen JCL (AP1, AP2) |
| F5 | Runs, steps and spool text (M3, M4) |
| F6 | Backend `LWDM211` and `LWDM304`, the LWW folders, build, upload, trying it on t01 |

The backend modules can be built at any point before F6. The UI runs on the
mocks until then.

## Setting it up on t01

First, the move from `/lwd` to `/lwdeploy` (2026-11-15). The app, the API and
the LWW folder now live under `/lwdeploy`; the folder keeps its ID
`LD000000`. On t01:
- **LWW folder:** `python python/uploadLWW.py --rename` gives folder
  `LD000000` its new name. Without `--rename` the upload stops while the folder
  is still `/lwd`. Whether LWW then moves the paths of the subfolders and files
  along with it is not known yet: check `/lwdeploy/API/v1/token` afterwards.
  If it doesn't work, delete `/lwd` in LWW and upload again; save
  `sso_config.json` first, as only LWW has it.
- **Result step:** the setting `LWDPATH` in TBLWD001 becomes
  `/lwdeploy/API/v1` (`UPDATE ... SET TABVALUE = '/lwdeploy/API/v1' WHERE
  TABLEID = 'SETTINGS' AND TABKEY = 'LWDPATH'`, or rerun `DDL/SETTINGS`).
  Jobs submitted before the change still have the old path in their
  `LWDCONF`.
- **Scheduler:** `pathPrefix` in the tick job's config file on z/OS UNIX,
  if it sets one.
- **Entra:** the redirect URI in the app registration and in
  `sso_config.json`, if it names `/lwd/auth`.
- **Scripts:** the `testIteration*.py` scripts and `tick.py` already use the
  new path.

Then:

1. **Build and deploy:** `. ./setenv`, `build`, then `python python/deploy.py`.
   New: `LWDC211`, `LWDM211`, `LWDC304`, `LWDM304` (DEPLOY binds their
   packages). The generated files are in git already; after a change to
   `genlww.py`, run `python python/genoas.py` and `python python/genlww.py`
   first.
2. **CICS, DB2 and RACF:** submit `BINDPLAN` (the new plan `LWDT01P`),
   `CICSCSD` and `RACF` again for the new transaction `LWDP`, and install
   the transaction and its DB2ENTRY. Install the new programs `LWDC211`,
   `LWDM211`, `LWDC304` and `LWDM304`, as for the other `LWDU` programs.
3. **Frontend:** `npm run build` in `lwdeploy-frontend`. It writes
   `index.html`, `assets/`, the LWW pages with `logout.html`, and a folder
   with a `.name` file per route into `lwdeploy/LWWAdmin/`; the API
   placeholders stay.
4. **LWW:** copy both specs from `openapi/` to `remoteOASDir`, then
   `python python/processYAML.py` and `python python/uploadLWW.py`. The
   placeholders `applications` and `deployments` exist already, so no new
   ones. Upload before committing the changed `.name` files: the script sends
   an existing file or folder (`index.html`, `assets/`) again only while its
   `.name` file is changed in the working tree, and that is how they move from
   `LWBL` to `LWDP`.
5. **Check on LWW** that a route folder (`/lwdeploy/deployment`) sends a
   request without a session to `redirect_to_login.html`, and that the Entra
   mapping covers `/lwdeploy`, as it does for `/ctf`.
6. **Without the UI:** `python python/testIteration5.py` tests the two new
   paths (below).

## Trying it

With `testIteration4.py`'s deployer and an approver who is someone else:
1. Sign in with RACF and with Entra. The start page shows DEMO, and the same
   userid both times.
2. Open DEMO. DEV shows the version of the last deployment that succeeded.
3. Deploy `V1.0.0` to DEV. The deployment page moves through Q and U to S
   without reloading, and both jobs show result O.
4. Open job 2's runs: steps with return codes, spool files, the text of
   `SYSTSPRT` of step `LWDRSO`.
5. Deploy `V1.0.1-BAD`: F with job 2 above its highest RC. Retry gives F
   again. Then cancel it, with a reason.
6. Deploy to an environment with approval. The requester sees no Approve
   button. The approver sees the request in `/lwdeploy/approvals` and on the
   start page, opens the JCL, and approves. After N approvers it is Q.
7. Reject one with an empty comment: refused. With a comment: J.
8. Open a deep link (`/lwdeploy/deployment?deplID=...`) in a new browser without a
   session. It goes to the sign-in page and back to the link afterwards.
9. Sign out, then press Back. The page asks for a sign-in again.

`python/testIteration5.py` tests the two new paths without the UI: the rows
for a member, for an approver-only user and for own requests, and `08 01` for
`appID` 0 without the own userid.

## To check on the first run

- The login redirect of the `/lwdeploy` folder: `/lwdeploy` without a session
  goes to the sign-in page, while `/lwdeploy/login` and `assets/` still load
  without one. If LWW passes the redirect down to subfolders, sign-in loops.

- `GET /deployments?appID=0&requestedBy_filter=` has no index on
  DEPLOYMENTS.CREATEDBY to use, so it reads the table backwards by DEPLID
  until it has 20 of the user's rows. Fine for t01; with many deployments an
  index (CREATEDBY, DEPLID) would help.

- That LWW's Entra mapping covers `/lwdeploy`, and that the userid is the same as
  with the RACF sign-in.
- That `loginRedirectWebpageId` brings the user back to the deep link (CTF's
  `returnTo` handling).
- Time zone: whether `startAfter` entered in the browser is the time the
  scheduler uses.
- The size of the JCL and spool responses, up to 32 KB of base64, over a slow
  connection.

## Not built yet

- **Admin and owner screens** with their API: applications, environment
  controls, allowlists, settings, the deployments of all applications, mark a
  run stuck (A1-A5); environments, templates with their history, variables,
  versions (O1-O4). [Iteration 6](10-iteration-6.md).
- **Profile (U2), `PUT /me`:** only useful once mail exists.
- **Mail (S5).**
- **The variables that went into a deployment** on the approval page. The
  frozen JCL shows the resolved values. A list of the variables, with the
  level each came from, needs the owner API's `GET /variables`.
- Everything on iteration 4's list that isn't mentioned above.
