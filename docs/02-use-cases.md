# Use cases

Actors are described in [01-actors.md](01-actors.md). Open points are listed at
the [end of this document](#open-points).

## Terms

| Term | Meaning |
|---|---|
| Application | A piece of z/OS software that is deployed as a whole, with its own groups, environments, jobs and versions |
| Environment | A place an application is deployed to (DEV, TST, ACC, PRD). Belongs to one application; environments are ordered |
| Version | A registered build of an application: a name plus the location of its artifacts (dataset HLQ or USS path) |
| Inventory | Which version was last deployed successfully in each environment |
| Job template | One JCL template of an application: steps only, with variables. An application has an ordered list of them |
| Variable | A name and value that fills in a template. Defined on the application, the environment or the version |
| Deployment | One request to put one version of one application into one environment, and everything that happens to it |
| Frozen JCL | The fully resolved JCL of each job of a deployment, stored when it is requested. It is what approvers see and what is submitted |
| Deploy userid | The RACF userid a deployment job runs under. Set per environment by an administrator |
| Access group, owner group | RACF groups set on an application. Members of the access group can see and deploy; members of the owner group maintain it |
| Deployer group, approver group | RACF groups set on an environment. They limit who can deploy there and name who approves |
| Promotion gate | An environment setting: a version can only be deployed there after it succeeded in the previous environment |

A deployment has a status, described with a diagram in
[01-actors.md](01-actors.md#deployment-lifecycle):

| Status | Meaning |
|---|---|
| REQUESTED | Just created; moves on straight away |
| AWAITING_APPROVAL | Waiting for N approvals |
| REJECTED, EXPIRED | Final: not approved |
| QUEUED | Approved or no approval needed; waiting for its time or for the environment |
| RUNNING | Jobs being submitted or running |
| FAILED | A job ended above its highest return code, or didn't end; waits for retry or cancel |
| SUCCEEDED | Final: all jobs within their highest return code; inventory updated |
| CANCELLED | Final: stopped by a person |

Each job of a deployment has its own status: WAITING, SUBMITTED, ENDED (with
return code), FAILED, SKIPPED.

## Everyone

### U1 Sign in and out
- **Goal:** get a session.
- **Preconditions:** a RACF userid.
- **Main flow:**
  1. The user chooses RACF or Entra sign-in.
  2. RACF: the LWW login page checks userid and passphrase. Entra: LWW's SSO
     redirect signs the user in and maps the Entra identity to a RACF userid.
  3. The UI asks the backend who the user is: userid, email, administrator or
     not, and the applications the user has a role in.
  4. Signing out ends the session.
- **Exceptions:** wrong credentials: one generic message. No role in any
  application and not an administrator: the user sees an empty start page that
  says to ask an administrator for access.
- **Rules:** the first call of a userid creates its user row; there is no
  registration. Its email address follows with the next run of S4.

### U2 Maintain own profile
- **Goal:** get the notifications the user wants.
- **Preconditions:** signed in.
- **Main flow:** 1. The user opens the profile and sees the email address
  LWD knows. 2. The user changes the notification settings: approvals waiting
  for me, my deployments ended, deployments of my applications ended.
- **Exceptions:** none beyond normal validation.
- **Rules:**
  - The email address comes from RACF, the `WAEMAIL` field of the user's
    WORKATTR segment, and can't be changed in LWD. A wrong or missing address is
    corrected in RACF; LWD picks it up with the next run of S4.
  - A user without an email address gets no email, only what the UI shows.
  - Only the user can change their own notification settings.

## Member

### M1 Browse my applications
- **Goal:** find an application.
- **Preconditions:** signed in.
- **Main flow:** 1. The system lists the applications the user is a member,
  owner or approver of, with the user's role in each. 2. The user opens one and
  sees its description, groups, environments in order and the latest
  deployments.
- **Exceptions:** none: no applications is an empty list.
- **Rules:** applications the user has no role in are not shown at all, not
  even their names. Administrators see every application (A4).

### M2 View inventory
- **Goal:** see what runs where.
- **Preconditions:** the user can see the application.
- **Main flow:** the system shows each environment with the version last
  deployed successfully there, when and by whom, and whether a deployment is
  running or queued.
- **Exceptions:** nothing deployed yet: the environment shows no version.
- **Rules:** only SUCCEEDED deployments change the inventory. After a FAILED
  deployment the environment is marked as such, because it may be half
  deployed.

### M3 View deployment history and details
- **Goal:** see what happened.
- **Preconditions:** the user can see the application.
- **Main flow:** 1. The system lists deployments, newest first, filtered by
  environment, version, status or requester. 2. The user opens one and sees the
  version, environment, requester, times, approvals with comments, the frozen
  JCL per job, and per job its status, JES job ID and return codes per step.
- **Exceptions:** unknown or not visible: not found.
- **Rules:** the list is paged.

### M4 View job output
- **Goal:** find out why a job did what it did.
- **Preconditions:** as M3; the output has been collected (S3).
- **Main flow:** 1. The user opens a job of a deployment. 2. The system shows
  the list of spool files and, per file, its lines.
- **Exceptions:** not collected yet: the UI says so and polls. Purged after the
  retention time: the UI says so; the return codes stay.
- **Rules:** output is large, so it is fetched per file and in pages.

## Deployer

### D1 Request a deployment
- **Goal:** get a version into an environment.
- **Preconditions:** the user is a deployer for the environment; the version is
  registered and not retired.
- **Main flow:**
  1. The user chooses application, version and environment, and optionally a
     start time.
  2. The system checks the promotion gate, if the environment has one.
  3. The system resolves every job template with the variables and freezes the
     JCL, together with the deploy userid it will run under.
  4. The system stores the deployment as REQUESTED and moves it on:
     AWAITING_APPROVAL if the environment needs approval, otherwise QUEUED.
  5. Approvers are notified (S5).
- **Exceptions:**
  - Gate not passed: rejected, naming the previous environment.
  - A variable used in a template has no value: rejected, listing the
    variables.
  - Start time in the past: treated as "now".
  - The application has no job templates, or the environment has no deploy
    userid, or it needs approval but has no approver group: rejected.
- **Rules:**
  - Variables are taken from the version, then the environment, then the
    application; the first one found wins. Built-in variables (application,
    environment, version name, version location, deployment ID) can't be
    overridden.
  - The frozen JCL holds the steps only. At every submission the system adds
    the JOB statement (a job name that contains the run key, `USER=` the frozen
    deploy userid) and the result step (S2) at the end (S1).
  - Later changes to templates or variables don't change a requested
    deployment. To pick them up, cancel and request again.
  - Rollback is just this use case with an earlier version.
  - Several deployments can be requested for the same environment; they run one
    at a time.

### D2 Follow a deployment
- **Goal:** know how it is going.
- **Preconditions:** as M3.
- **Main flow:** the UI polls the deployment and shows the status of the
  deployment and of each job as they change.
- **Exceptions:** none beyond M3.
- **Rules:** the requester is notified when it ends (S5).

### D3 Cancel a deployment
- **Goal:** stop a deployment that is no longer wanted.
- **Preconditions:** the user is the requester or a deployer for the
  environment; the deployment is REQUESTED, AWAITING_APPROVAL, QUEUED, FAILED,
  or RUNNING with no job submitted or running.
- **Main flow:** 1. The user confirms, with a reason. 2. The system sets the
  deployment CANCELLED and the jobs not yet run SKIPPED.
- **Exceptions:** a job is submitted or running: rejected; wait until it ends.
- **Rules:**
  - The app never cancels a job in JES. Someone with the authority does that in
    SDSF; the job then ends with an abend and the deployment becomes FAILED,
    after which it can be cancelled here.
  - Cancelling a FAILED deployment doesn't undo what its jobs did. The
    environment stays marked as possibly half deployed (M2) until a deployment
    there succeeds.

### D4 Retry or resume a failed deployment
- **Goal:** finish a deployment after the cause of a failure is fixed.
- **Preconditions:** the user is a deployer for the environment; the deployment
  is FAILED.
- **Main flow:** the user chooses one of:
  - **Retry:** the failed job is submitted again, and the rest follows.
  - **Continue:** the failed job is marked SKIPPED, with a reason, and the next
    job is submitted. Used when the problem was fixed by hand.
- **Exceptions:** not FAILED: rejected.
- **Rules:**
  - Both use the frozen JCL unchanged, so no new approval is needed. Changing
    the JCL means a new deployment, which goes through approval again.
  - Who retried or continued, and why, is recorded.
  - Jobs must be written so that running them twice is safe.

## Approver

### AP1 List requests waiting for me
- **Goal:** know what needs a decision.
- **Preconditions:** signed in.
- **Main flow:** the system lists the deployments in AWAITING_APPROVAL for
  environments whose approver group the user is in, oldest first, with the
  approvals already given. The start page shows the count.
- **Exceptions:** none: nothing waiting is an empty list.
- **Rules:** the user's own requests, and requests the user already approved,
  are not listed.

### AP2 Approve or reject
- **Goal:** decide on a deployment.
- **Preconditions:** the deployment is AWAITING_APPROVAL; the user is in the
  environment's approver group; the user did not request it and hasn't approved
  it yet.
- **Main flow:**
  1. The user opens the request and sees the version, its location and
     variables, the frozen JCL of every job and the deploy userid.
  2. The user approves or rejects, with a comment.
  3. Approve: if this is the N-th approval, the deployment becomes QUEUED.
     Reject: the deployment becomes REJECTED.
  4. The requester is notified (S5).
- **Exceptions:** own request, already approved, or not waiting anymore:
  rejected.
- **Rules:**
  - A comment is required when rejecting.
  - One rejection is enough to reject.
  - N is taken from the environment at the time of the request; changing it
    later doesn't affect requests already waiting.
  - Two approvals by the same userid count once.

## Application owner

### O1 Maintain environments
- **Goal:** describe where the application goes.
- **Preconditions:** the user is in the application's owner group.
- **Main flow:** 1. Add an environment with name and description. 2. Change
  the order. 3. Maintain its variables. 4. Switch the promotion gate on or off.
  5. Delete an environment.
- **Exceptions:** name taken within the application: asked for another. Delete
  an environment with deployments: rejected. A 21st environment: rejected.
- **Rules:**
  - The promotion gate looks at the environment directly before this one in
    the order.
  - A new environment can't be deployed to until an administrator has set its
    deploy userid (A2), and it starts with approval switched on, so an
    environment is never unprotected by accident.

### O2 Maintain job templates
- **Goal:** define what a deployment does.
- **Preconditions:** as O1.
- **Main flow:** 1. Add a template with name, JCL steps and highest acceptable
  return code. 2. Edit it. 3. Change the order. 4. Delete it. 5. View the
  history of a template and compare two versions.
- **Exceptions:**
  - The JCL contains a JOB statement, `USER=`, `PASSWORD=` or JES2 or JES3
    control statements: rejected, naming the line.
  - More than 300 lines, a line longer than 80 characters, or a 21st active
    template of the application: rejected.
  - The JCL uses a variable that is defined nowhere: a warning, not an error,
    because it may be defined on a version later.
  - Lines longer than 80 columns after the variable values are filled in:
    found when a deployment is requested (D1), and rejected there. A JCL
    statement that passes column 71 gives a warning.
- **Rules:**
  - Every change is kept as a new template version, with userid and time.
  - Changes don't affect deployments already requested (frozen JCL).
  - Templates are the same in every environment; differences go into
    environment variables.

### O3 Maintain application variables
- **Goal:** values shared by all environments.
- **Preconditions:** as O1.
- **Main flow:** add, change or delete a variable with name, value and
  description.
- **Exceptions:** name not valid or a built-in: rejected.
- **Rules:** variables are not secret: the UI shows them to every member and
  warns not to put passwords in them.

### O4 Register and maintain versions
- **Goal:** make a build deployable.
- **Preconditions:** as O1; also used by the CI pipeline through the API.
- **Main flow:** 1. Register a version with name, location, description and
  version variables. 2. Edit it while it has never been deployed. 3. Retire it.
- **Exceptions:** name taken within the application: rejected. Edit a version
  that was ever requested for deployment: rejected.
- **Rules:**
  - Versions can't be deleted once requested, only retired. A retired version
    can't be requested anymore, but stays in the history and inventory.
  - The system doesn't check that the location exists; the jobs do.

## Administrator

### A1 Maintain applications
- **Goal:** put an application under LWD.
- **Preconditions:** signed in as administrator.
- **Main flow:** 1. Create an application with a name, description, access
  group and owner group. 2. Change them. 3. Delete an application.
- **Exceptions:** group not in the allowlist: rejected. Delete an application
  with deployments: rejected.
- **Rules:** the groups come from the allowlist (A3).

### A2 Set environment controls
- **Goal:** decide how protected an environment is.
- **Preconditions:** signed in as administrator; the environment exists.
- **Main flow:** set the deploy userid, whether approval is required, the
  approver group, the number of approvals N, and the deployer group (optional).
- **Exceptions:** userid or group not in the allowlist: rejected. N < 1 with
  approval required: rejected.
- **Rules:**
  - Changes apply to deployments requested afterwards. A deployment already
    requested keeps the deploy userid and approval rules it was requested with.
  - The approver group should have more than N members besides any requester;
    the system can't check this and the UI says so.

### A3 Maintain allowlists
- **Goal:** limit which RACF groups and userids LWD may use.
- **Preconditions:** signed in as administrator.
- **Main flow:** add or remove RACF groups and deploy userids, with a
  description.
- **Exceptions:** removing an entry still in use by an application or
  environment: rejected.
- **Rules:** every RACF group in the allowlist needs a FACILITY profile
  `LWD.<env>.GRP.<group>` (M7). The submit userid needs surrogate access to
  every deploy userid in
  the allowlist (`SURROGAT` class, `userid.SUBMIT`). Adding one here doesn't do
  that; it is a RACF change by the security administrator.

### A4 Monitor all deployments
- **Goal:** see everything that goes on.
- **Preconditions:** signed in as administrator.
- **Main flow:** 1. List deployments and jobs over all applications, filtered
  by status, application, environment or requester. 2. Open any of them as in
  M3 and M4. 3. Mark a submitted run stuck when its job ended in JES without
  a result (its result step failed): the run fails with result T at once, as
  S4 does after `JOBMINS`, so the deployment can be retried or cancelled.
- **Exceptions:** the run isn't submitted any more: nothing changes.
- **Rules:** administrators can't approve or deploy because they are
  administrators; for that they need to be in the groups like anyone else.

### A5 Maintain settings
- **Goal:** tune the timing.
- **Preconditions:** signed in as administrator.
- **Main flow:** change the settings: time limit for approval, time after which
  a submitted job counts as stuck, retention of job output, and the sender
  address for email.
- **Exceptions:** values out of range: rejected.

## System

### S1 Start a deployment and submit its jobs
- **Goal:** run the jobs, one after the other.
- **Trigger:** a deployment becomes QUEUED and its time has come (D1, AP2, S4),
  a job ended within its highest return code (S2), or D4.
- **Preconditions:** no other deployment in the environment is RUNNING or
  FAILED.
- **Main flow:** 1. The deployment becomes RUNNING. 2. The backend records a
  new run of the job and starts the submit task with the run and a token.
  3. The task checks the token, sets the run SUBMITTED only if it is still NEW,
  and writes the JOB statement, the frozen JCL and the result step to
  `INTRDR` with the CICS SPOOL commands. When the environment has an
  execution node, a `/*XEQ` statement sends the job there. 4. The JES job ID
  is recorded by the result step (S2).
- **Exceptions:** submit failed: the job and deployment become FAILED. Wrong
  token or a job that isn't WAITING: nothing is submitted. Environment busy:
  the deployment stays QUEUED.
- **Rules:**
  - Only frozen JCL is submitted. Nothing typed in a request goes into JCL.
  - Every job goes through the submit task, the first and the next ones
    alike (M9).
  - A FAILED deployment blocks its environment until it is retried, continued
    or cancelled, because the environment may be half deployed.
  - Queued deployments for an environment start in the order of their start
    time, then of request.

### S2 Record a job result
- **Goal:** let LWD know how a job ended and move on.
- **Trigger:** the result step, the last step of every job, which always runs.
- **Main flow:** 1. The step records whether the job stayed within its highest
  acceptable return code, went above it, or abended. 2. Within: the job is ENDED
  and the next job is submitted (S1); after the last job, the deployment is
  SUCCEEDED and the inventory is updated. 3. Above it: the job and deployment
  become FAILED.
- **Exceptions:** the step doesn't run, for example after a JCL error or a
  cancel in JES: found by S4.
- **Rules:**
  - The step sends the outcome to `POST /jobResults`, signed in as the deploy
    userid with an Entra access token, asked for with a client assertion
    signed by the deploy userid's certificate in RACF, so any CICS region
    behind LWW can take it. It has no DB2 access of its own, so the job
    can run on any LPAR that reaches LWW. LWD only accepts it from the deploy
    userid of the deployment, for the job name of the run, once.
  - Requester and, if they wish, owners are notified when the deployment ends
    (S5).

### S3 Collect job output
- **Goal:** show job output in the UI.
- **Trigger:** the scheduled batch job (S4) runs, and a run has ended or
  failed and its output isn't collected yet.
- **Main flow:** 1. The runs to collect are listed. 2. Each job is found in
  JES with SDSF by its job name, which is unique per run. 3. Its spool data
  sets are stored in DB2 per spool file, with DD, step and procedure step
  names. 4. The return code or abend of every step is taken from the system
  messages in `JESYSMSG` (`IEF142I`, `IEF472I`, `IEF202I`, `IEF206I`,
  `IEF272I`), the job's from the return code SDSF shows.
- **Exceptions:** the job is still running: tried again later. Not found in
  JES: tried again until the run ended more than `JOBMINS` minutes ago, then
  marked as without output. A run that never reached JES: without output at
  once.
- **Rules:** the original output stays in JES for SDSF. At most `OUTLINES`
  lines per run are stored, the rest is marked as cut off. Stored output is
  purged after `OUTDAYS` days (S4).

### S4 Scheduled batch
- **Goal:** time-based work gets done, and nothing waits forever without anyone
  knowing.
- **Trigger:** a scheduled batch job that calls `POST /schedulerTicks` (M10).
- **Main flow:**
  1. Start QUEUED deployments whose time has come (S1).
  2. Mark jobs that were submitted longer ago than the stuck time and have no
     result as FAILED, so the deployment shows as FAILED.
  3. Set deployments waiting for approval longer than the time limit to
     EXPIRED.
  4. Delete job output older than the retention time.
  5. Refresh the email address of every user from RACF (`WAEMAIL`), with
     `IRRXUTIL` in a REXX step, and store it in DB2.
- **Exceptions:** a late result from S2 still updates the job, and can turn a
  FAILED job into ENDED. A userid that no longer exists in RACF gets an empty
  address.
- **Rules:** all limits are settings (A5). Step 5 needs a batch job even if the
  other steps move to a CICS interval task; its userid needs authority to read
  `WAEMAIL` of the users (M8).

### S5 Send notifications
- **Goal:** tell people about things that need them, without them watching the
  screen.
- **Trigger:** D1 (approvers), AP2 (requester), S2 (requester and those who
  asked for it), S4 (requester, on expiry).
- **Main flow:** the system queues a mail per recipient with an email address
  and the matching setting, and the mail is sent.
- **Exceptions:** sending fails: tried again later, then dropped with a
  message. No address: nothing sent.
- **Rules:**
  - Mail is a convenience; the UI always shows the same information.
  - Mails contain a link to the deployment and no JCL or job output.

## Open points

### Decided

1. **Versions are registered**, with a location, by hand or by CI through the
   API. LWD keeps an inventory per environment.
2. **Environments belong to one application** and are ordered.
3. **Each environment has a deploy userid**, set by an administrator from an
   allowlist. People need no write access to the target libraries; approval is
   the control.
4. **Owners maintain environments, templates, variables and versions;**
   administrators set the security-relevant controls (A2).
5. **Approval:** per environment, N distinct approvers from an approver group,
   never the requester. One rejection is enough.
6. **Access:** the access group sees and deploys; an environment's deployer
   group can limit who deploys there.
7. **Promotion gate:** optional per environment.
8. **Sign-in:** RACF passphrase or Entra, to the same RACF userid.
9. **Jobs:** one ordered list of templates per application, the same in every
   environment, differences in variables.
10. **JCL control:** JCL is frozen at request time and shown to approvers;
    templates keep their history; the JOB statement is generated.
11. **Failure:** retry or continue without new approval, using the frozen JCL.
12. **Scheduling:** now or at a set time; no maintenance windows.
13. **Notifications:** UI polling plus email; the address comes from RACF
    (`WAEMAIL`), refreshed by S4.
14. **One application per deployment.**
15. **One active deployment per environment;** a FAILED one also blocks it.

### Mainframe decisions

| # | Topic | Decision |
|---|---|---|
| M1 | Access paths | Separate CICS transactions for user and admin paths, as in CTF. No public path |
| M2 | Job submission | CICS SPOOL in a separate task, under a submit userid with surrogate access to every deploy userid (CTF M2) |
| M3 | Job results | A result step run under JCL `IF` tests, so it knows: within the highest RC, above it, or abend. Since iteration 4 a REXX step that calls `POST /jobResults` as the deploy userid, instead of static SQL in batch (CTFM915 pattern) ([08-iteration-4.md](08-iteration-4.md)); since iteration 8 signed in with an Entra access token instead of a PassTicket ([12-iteration-8.md](12-iteration-8.md)). Exact step return codes come from the output (M4) |
| M4 | Job output | Copied from JES by the scheduled batch job, after the tick: a REXX step reads the output of each ended job with SDSF (ST panel, by job name), a static-SQL COBOL step stores it in DB2. Not the CICS SPOOL interface, which gives no job, DD or step names ([07-iteration-3.md](07-iteration-3.md)) |
| M5 | Administrator | COBOL checks a FACILITY resource (`EXEC CICS QUERY SECURITY`) |
| M6 | Environments | `t01` only for now; others follow later |
| M7 | Group check | One discrete FACILITY profile per allowlisted group, `LWD.<env>.GRP.<group>`, UACC(NONE), with the group on its access list with READ. COBOL checks it with `QUERY SECURITY`. No assembler |
| M8 | Email address | RACF WORKATTR `WAEMAIL`, read in the scheduled batch with `IRRXUTIL`. The batch userid needs READ on FACILITY `IRR.RADMIN.LISTUSER` and access to the field (FIELD class `USER.WORKATTR.WAEMAIL`) |
| M9 | Next job | The result of job N (`POST /jobResults`) creates a run of job N+1 and starts the submit task for it, as for the first job: CICS submits every job, so the deploy userid needs no internal reader and no DB2 in batch. Iterations 1 to 3 had the result step submit job N+1 itself ([08-iteration-4.md](08-iteration-4.md)) |
| M12 | Execution node | Per environment an optional JES2 node (`EXECNODE`, set by an admin): LWDM920 adds `/*XEQ`. The output comes back to the local node for M4, found by job name only ([08-iteration-4.md](08-iteration-4.md)) |
| M10 | Periodic work | A scheduled batch job (any workload scheduler) calls `POST /schedulerTicks` every few minutes, signed in to Entra with client credentials, under its own userid and transaction. The heartbeat is outside CICS, and a failed tick is a job with a return code other than 0. Starts that can happen at once do: approval, cancel, retry and continue start the next deployment themselves ([06-iteration-2.md](06-iteration-2.md)) |
| M11 | Continue | Allowed, as D4 describes: a deployer skips the failed job with a reason, without new approval |
| M13 | Email | Queued in `MAILQUEUE` with the event; sent by the tick from CICS (`SPOOLOPEN OUTPUT` to the CSSMTP writer), at most `MAILMAX` per tick ([11-iteration-7.md](11-iteration-7.md)) |

### Still to confirm

- **Output size:** how big job output may get in DB2 (`OUTLINES`, `OUTDAYS`).

## Out of scope for v1

Releases of several applications, targets other than z/OS, agents, automatic
rollback jobs, cancelling a job in JES from the app, maintenance windows,
webhooks, secret variables, storing artifacts in LWD, comparing the frozen JCL
with that of the previous deployment, a 3270 transaction.
