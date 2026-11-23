# Iteration 7: notifications and the profile

Since iteration 6, everyone works in the web UI, but only while they look at
it. An approver learns about a request by opening the start page, and a
requester learns that a deployment ended by keeping its page open. Mail was
left out until now (S5), and so was the profile (U2) that switches it on and
off, as the iteration 6 doc planned.

This iteration builds:
- **The email addresses (S4 step 5, M8):** a daily batch job copies RACF
  `WAEMAIL` into `USERS.EMAIL`. Nothing fills that column today.
- **The queue (S5):** every event that someone should hear about queues mails
  in `MAILQUEUE`, in the same unit of work as the event.
- **Sending (S5):** the tick sends the queued mails through CSSMTP.
- **The profile (U2):** `PUT /me` and a profile page in the UI.

Built: the profile page against the frontend's mock (F12), tried on t01
(2026-11-16), and the backend ("Built: backend" below). The backend was tried on t01 (2026-11-16) with
`testIteration7.py`: `LWDMAIL` copies the addresses, `PUT /me` switches the
settings, and a deployment's result queues a mail for its requester only when
`notifyOwn` is Y. What it took is in "To check on the first run". Whether
CSSMTP delivers the mails is checked in the inbox, not by the script.

## Decisions

| Subject | Decision |
|---|---|
| Route out of z/OS | CICS, from the tick (agreed 2026-11-15). After `LWDM930` has committed, the tick's wrapper `LWDC930` links to a new CICS program `LWDC950`, which sends the queued mails with `SPOOLOPEN OUTPUT` to the JES writer of CSSMTP, as `LWDC910` writes jobs to `INTRDR`. No new transaction, `DB2ENTRY` or RACF profile: it runs in the tick's task (`LWDQ`, the scheduler's userid) |
| CSSMTP | Runs on t01 and reads writer `CSSMTP` (2026-11-15). Writer and class are settings from `envs/<env>.yaml`: `MAILWRTR` (`CSSMTP`) and `MAILCLS`. An empty `MAILWRTR` switches mail off: nothing is queued |
| Recipients | From LWD's own tables, as CICS can't list the members of a RACF group: `USERGROUPS`, the cache of each user's allowlisted groups since their last sign-in (`GRPMINS`). A user who never signed in to LWD gets no mail, and a stale cache may send one to a user who left a group; the mail only links to LWD, which checks access again |
| Who gets what | Nobody gets a mail about what they did themselves (the CICS userid of the event). **A** approval waiting: the approvers of the deployment (its `APPROVERGROUP` in their cache) with `NOTIFYAPPROVE` Y, never the requester. **D** decided (rejected, or the last approval): the requester with `NOTIFYOWN` Y. **E** ended (S, F, C): the requester with `NOTIFYOWN` Y, and the owners of the application (owner group in their cache) with `NOTIFYAPP` Y. **X** expired: the requester with `NOTIFYOWN` Y. Never to a user without an address; one mail per user per event |
| Where they are queued | Where every status change of a deployment already goes: `R650-ADD-EVENT` in `LWDDEPP`, which adds the history event, performs `R750-QUEUE-MAIL` in a new copybook `LWDMALP` (working storage `LWDMALW`) after it. The event type decides the mail: R while the deployment waits for approval gives A; Q (the last approval) and J give D; E gives X; S, F and C give E. So no module queues mail itself, and every module that copies `LWDDEPP` copies `LWDMALP` too |
| Content | Subject and body built by `R750-QUEUE-MAIL`, in plain text: what happened, application, environment, version, requester, and the link `<MAILURL>/deployment?deplID=n`. Never JCL or output (S5). Only characters CSSMTP's EBCDIC-to-ASCII translation keeps: a request note goes in as it is, with other characters replaced by `?` |
| Sending | Oldest first, at most `MAILMAX` (setting, 50) per tick, one unit of work per mail: `SPOOLCLOSE`, then status S. A failure counts an attempt; after 3 the mail gets F and the tick writes a message to the CICS log. Status N mails older than `APPRHRS` are dropped as F, so a long CSSMTP outage doesn't flood people with old news |
| Purge | `LWDM940` (the collector's first step) deletes S and F mails older than `OUTDAYS`, as it does output |
| Email refresh | A daily job `LWDMAIL` (any workload scheduler), as M8 decided: a static-SQL COBOL step lists the userids of `USERS`, a REXX step reads their `WAEMAIL` with `IRRXUTIL`, a COBOL step stores the addresses. A userid without one, or gone from RACF, gets NULL. Its userid needs READ on FACILITY `IRR.RADMIN.LISTUSER` and `IRR.LISTUSER`, and on FIELD `USER.WORKATTR.WAEMAIL` |
| Profile | `PUT /me` (`LWDM002`, U): the three notification settings, Y or N, for the user's own row only. The address stays read-only: it comes from RACF (U2) |
| Tick response | `mailsSent`, the mails sent in this tick, joins the response of `POST /schedulerTicks`; `tick.py` prints it |

## Backend

| Method and path | Module | Use case |
|---|---|---|
| PUT `/me` | `LWDM002` (U) | U2 |
| POST `/schedulerTicks` | `LWDM930`, then `LWDC950` from its wrapper | S4, S5 |

Not reachable through LWW:

| Program | What it does |
|---|---|
| `LWDC950` | CICS: per mail, asks `LWDM950` for the next one, writes it to the CSSMTP writer, reports the result. Hand-written, as `LWDC910` |
| `LWDM950` | DB2: the next mail as SMTP lines (`HELO`, `MAIL FROM`, `RCPT TO`, `DATA`, headers, body, `.`, `QUIT`), then sent or failed |
| `LWDM960` | Batch DB2 (`LWDMAIL`): the userids to look up, and afterwards their addresses |
| `LWDR961` | Batch REXX (`LWDMAIL`): `WAEMAIL` per userid, with `IRRXUTIL` |

Copybooks: `LWDMALW` and `LWDMALP` (queueing), included by the modules that
copy `LWDDEPP`, and by `LWDM411`, `LWDM418`, `LWDM511` and `LWDM930`.

`genlww.py`:
- `updateCurrentUser` with `LWDM002`, `OPCODE` U, so the profile can grow
  without a second module;
- `mailsSent` in `TICK`, and a `mail` option for the wrapper of the tick:
  after the commit it links to `LWDC950` and puts the count in the IO area.

Settings (from `envs/<env>.yaml` through `DDL/SETTINGS`): `MAILWRTR`,
`MAILCLS`, `MAILMAX`. `MAILFROM` and `MAILURL` exist since iteration 1, and
administrators can change them since iteration 6.

## Screens

| Route | Screen | Use cases | API calls |
|---|---|---|---|
| `/lwdeploy/profile` | The address LWD knows (read-only, with where it comes from), the three notification settings, save | U2 | `GET /me`, `PUT /me` |

- The user badge in the top bar opens the profile.
- Without an address the page says that no mail can be sent, and that the
  address is set in RACF.
- A new route folder `profile`, under `LWDU` with the login redirect, as the
  other routes.

## Mocks and tests

As before: the frontend's mock gets `PUT /me` first, and the profile page is
built against it. `PLAN-ADMIN.md` gets the step:

| Step | Content |
|---|---|
| F12 | Profile page, `PUT /me` in the mock |

`python/testIteration7.py`:
1. `PUT /me`: switch each setting off and on again; a value other than Y or
   N is `08 02`.
2. With the deployer's settings on, deploy V1.0.0 of DEMO to DEV and wait for
   it to end.
3. The tick's `mailsSent` goes up; the script asks to check the deployer's
   inbox for the "ended" mail.
4. With `NOTIFYOWN` N, deploy again: no mail.

## Built: backend

| Program | What it is |
|---|---|
| `LWDM002`, `LWDC002` | `PUT /me`, from `genlww.py`. Saves the settings, then answers through `LWDM302` (`GET /me`), which also creates the user row on a first call |
| `LWDMALW`, `LWDMALP` | Queueing, performed by `R650-ADD-EVENT`. Included by `LWDM411`, `LWDM418`, `LWDM511`, `LWDM514`, `LWDM910`, `LWDM915`, `LWDM916` and `LWDM930` |
| `LWDC930` | From `genlww.py`, with the `mail` option: after its commit it links to `LWDC950` and puts the count in `mailsSent` |
| `LWDC950` | CICS, hand-written: `SPOOLOPEN OUTPUT NODE('LOCAL') USERID(<MAILWRTR>) CLASS(<MAILCLS>) RECORDLENGTH(255) NOCC`, one spool data set per mail, each written record as long as its line |
| `LWDM950`, `LLWDM950` | DB2, hand-written copybook as `LLWDM920`: P settings and dropping old mails, N the next mail as SMTP lines, S sent, F failed |
| `LWDM940` | Also deletes sent and failed mails older than `OUTDAYS` |
| `LWDM960`, `LWDR961`, `JCL/LWDMAIL` | The daily refresh. `LWDR961` marks a userid `IRRXUTIL` failed for (X), so its address in DB2 stays; it ends with RC 8 when every userid failed, so a missing authority never wipes the addresses |

Decided while building:
- **The setting is `MAILCLS`**, not `MAILCLASS`: a setting key has at most 8
  characters (`TABKEY`). In `envs/t01.yaml` the values are `MAILWRITER`,
  `MAILCLASS` and `MAILMAX`.
- **SMTP lines:** `HELO` with the domain of `MAILFROM`, then `MAIL FROM`,
  `RCPT TO`, `DATA`, the headers `From: LWD <MAILFROM>`, `To:` and
  `Subject:` (folded every 70 characters), an empty line, the body wrapped at
  72 characters (a line that starts with a dot gets a second one), `.` and
  `QUIT`.
- **The body:** what happened, deployment, application, version,
  environment, requester, the link to the deployment, and the link to the
  profile.
- **The tick sends at most `MAILMAX` mails, sent or not**, so a CSSMTP that
  refuses everything costs at most that many attempts per tick.
- **`python/testIteration7.py`** walks through "Mocks and tests": `PUT /me`,
  then a deployment with and one without `notifyOwn`, and says where to look
  for the mail ("mails sent" in LWDTICK's output, and the inbox).

## Setting it up on t01

1. **Settings:** `MAILWRTR`, `MAILCLS`, `MAILMAX` in `envs/t01.yaml`; run
   `DDL/SETTINGS` again (it puts every setting back to the file's values).
2. **Build and deploy:** the new and changed modules: every module that
   copies `LWDDEPP` (`LWDM411`, `LWDM418`, `LWDM511`, `LWDM514`, `LWDM910`,
   `LWDM915`, `LWDM916`, `LWDM930`), `LWDC930`, the new `LWDM002`, `LWDC002`,
   `LWDM950`, `LWDC950`, `LWDM960`, `LWDM940`, and REXX `LWDR961` (to
   `EXECLIB`, by `DEPLOY.zmake`). `JCL/LWDMAIL` with the other JCL.
3. **CICS:** install `LWDC002`, `LWDM002`, `LWDC950` and `LWDM950`;
   `NEWCOPY` the changed ones.
4. **LWW:** `processYAML.py`, `uploadLWW.py` (the profile folder and the new
   build).
5. **RACF:** `JCL/RACF.jcl` gives the scheduler's userid, which runs
   `LWDMAIL`, READ on FACILITY `IRR.RADMIN.LISTUSER` and `IRR.LISTUSER`, and
   on FIELD `USER.WORKATTR.WAEMAIL`. The FIELD class must be active and
   RACLISTed.
6. **Schedule `LWDMAIL`** once a day, and run it once by hand before
   trying mail. It only reads the userids in `USERS`, which get their row at
   their first sign-in: a new user's address arrives with the first run after
   that.

## To check on the first run

- **The SPOOL options for an external writer:** `LWDC950` uses
  `NODE('LOCAL')` with `USERID` set to the writer name, and `CLASS`. If
  CSSMTP doesn't pick that up, the other way is `OUTDESCR` with
  `WRITER(CSSMTP)`.
- **Records shorter than `RECORDLENGTH(255)`:** whether CICS writes them as
  they are or pads them with blanks, and whether CSSMTP minds trailing blanks
  on its commands.
- **CSSMTP's view of the sender:** whether it needs the `HELO` domain to match
  its configuration, and what it does with a recipient it can't reach (a
  bounce to `MAILFROM`).
- **`IRRXUTIL` under the batch userid:** found on t01 (2026-11-16). R_admin
  answers `12 12 8 8 24` ("caller not authorized") in two cases: without READ
  on FACILITY `IRR.RADMIN.LISTUSER`, and without any authority over the user
  being read. Field-level access to the address alone isn't enough, also
  with the FIELD class active and RACLISTed: the scheduler's userid needs READ
  on FACILITY `IRR.LISTUSER` too, which lets it list the base segment of other
  users. That doesn't reach users with SPECIAL, AUDITOR or OPERATIONS: they
  stay `12 12 8 8 24`, `LWDR961` marks them X, and LWD keeps their address as
  it is (at first none), so they get no mail. `JCL/RACF.jcl` now defines and
  permits both FACILITY profiles, with a warning to look for a generic profile
  that covers `IRR.LISTUSER` first.
- **The FIELD class must be active and RACLISTed** for the address itself:
  otherwise R_admin answers RC 0 and leaves `WAEMAIL` out, and `LWDR961` takes
  that for "no address".
- **The FIELD profile name holds the segment:** `USER.WORKATTR.WAEMAIL`, not
  `USER.WAEMAIL` (found on t01, 2026-11-16). With the wrong name R_admin
  returned only the BASE segment, RC 0, and every userid came out without an
  address.

## Not built yet

- **Group members from RACF:** the daily job could also list the members of
  the allowlisted groups (`IRRXUTIL` on the group profile), so approvers who
  never signed in get mail too.
- **Multi-application releases** and the rest of "Out of scope for v1" in
  02-use-cases.md.
- **From iteration 4:**
  - `SYSAFF` within a JES2 MAS
  - removing `LWDM915` and `MODE-BATCH` of `LWDM920`
