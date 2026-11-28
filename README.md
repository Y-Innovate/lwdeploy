# lwdeploy

The backend of LWD, the Y-Innovate deployment manager for z/OS applications.
Owners register versions of their applications and keep JCL templates and
variables per environment; deployers request a version for an environment;
approvers allow it; LWD then submits the jobs under the environment's deploy
userid, records how each ended, collects their output and keeps the inventory
of what is deployed where. Everything lives in CICS, DB2 and RACF.

The REST API is served by **LWW**, a CICS extension that maps JSON requests to
COBOL copybooks, holds the browser sessions and hosts the web UI. The web UI
itself is a React app in its own repository,
[lwdeploy-frontend](https://github.com/Y-Innovate/lwdeploy-frontend); its
build output is committed here, in `LWWAdmin/`.

## How it fits together

```
Browser ──► LWW (in CICS) ──► COBOL wrapper LWDCnnn ──► module LWDMnnn ──► DB2
              │  serves the web UI (LWWAdmin/)               │
              │  sign-in: RACF passphrase,                   └─► submit task (CICS)
              │           Entra ID                                │ JES, USER= deploy userid
              └─ one CICS transaction per audience:               ▼
                 LWDU user, LWDA admin,                      deployment job
                 LWDQ scheduler, LWDJ result step            └─► result step ──► POST /jobResults
```

- **Roles come from RACF groups**, per application and per environment:
  member, deployer, approver, owner. One userid can own one application and
  approve another. LWD checks a FACILITY profile per group with
  `QUERY SECURITY` ([docs/01-actors.md](docs/01-actors.md)).
- **What is approved is what runs.** The JCL of every job is resolved and
  frozen when the deployment is requested; approvers see it, and the submit
  task submits it unchanged under the deploy userid. Only the submit userid
  has surrogate access to the deploy userids.
- **Every job reports its own result.** LWD adds a result step to each job:
  a REXX exec that signs in to Entra with a certificate of the deploy userid
  in RACF and calls `POST /jobResults`, which starts the next job
  ([docs/12-iteration-8.md](docs/12-iteration-8.md)). No secret is stored for
  it, and the call can land in any CICS region behind LWW.
- **A scheduled batch** (`JCL/LWDTICK.jcl`, every few minutes) calls
  `POST /schedulerTicks`, which starts queued deployments, marks stuck jobs,
  expires requests and sends the notification mails, and then collects job
  output from JES with SDSF. `JCL/LWDMAIL.jcl` refreshes the email addresses
  from RACF once a day.

## Repository layout

| Folder | What it holds |
|---|---|
| `COBOL/` | `LWDCnnn`: CICS wrappers, one per API operation. `LWDMnnn`: the modules with the logic and the SQL |
| `ASM/` | `LWDA990` (find the userid), `LWDA991` (random bytes and SHA-256 with CPACF), `LWDA992` (access check) |
| `REXX/` | The result step of every job (`LWDR916`), the output collector (`LWDR941`) and the email refresh (`LWDR961`) |
| `COPY/` | Copybooks: `LLWDMnnn` IO areas, `TBLWDnnn` table declarations, shared logic |
| `DDL/` | DB2 DDL, run in order (`AA0000nn`, see `$INFO.txt`), plus seed data and settings |
| `JCL/` | RACF definitions, CICS CSD definitions, plan binds, DDL runner, the scheduled batch and the sign-in test |
| `LKED/`, `OPTFILE/` | Link-edit and compile options per program |
| `ZMAKE/` | Build and deploy definitions (`BUILD.zmake`, `DEPLOY.zmake`) |
| `envs/` | Values per environment (`t01.yaml`, `t03.yaml`), filled into the DDL, JCL and builds |
| `openapi/` | The API spec (`lwd_1.0.0.yaml`) and LWW's processing steps for it (`lwd_2_1.0.0.yaml`) |
| `LWWAdmin/` | What LWW serves under `/lwdeploy`: the built web UI, LWW's sign-in pages, and one placeholder per API path whose hidden `.name` file sets its CICS transaction |
| `python/` | Build, deploy and upload scripts, the scheduler's tick, and the API tests |
| `docs/` | Design and build documentation, see below |

## Documentation

| Document | Contents |
|---|---|
| [01-actors.md](docs/01-actors.md) | Who uses the system, how each is identified, and the deployment lifecycle |
| [02-use-cases.md](docs/02-use-cases.md) | All use cases: member, deployer, approver, owner, administrator, system |
| [03-data-model.md](docs/03-data-model.md) | The DB2 tables, settings and status codes |
| [04-api.md](docs/04-api.md) | REST conventions, access per path, status and reason codes |
| [05](docs/05-iteration-1.md) to [12](docs/12-iteration-8.md) | The eight build iterations: what each added, design decisions, setup and tests |

## Requirements

- z/OS with CICS TS, Db2 for z/OS, RACF and JES2, and SDSF for the output
  collector. The modules use CPACF for random numbers and hashing.
- LWW installed in the CICS region, with its Admin API reachable.
- Microsoft Entra ID, for the scheduler's tick, the result step and, if you
  like, single sign-on.
- Java 21 or later on z/OS, and
  [jwt_signer](https://github.com/Y-Innovate/jwt_signer), with which the
  result step signs in.
- Python 3 with `jinja2`, `requests` and `PyYAML`: on z/OS (Unix System
  Services) for rendering, building and deploying, and on a workstation for
  uploading to LWW and running the API tests.

## Setting it up

[docs/05-iteration-1.md](docs/05-iteration-1.md#setting-it-up-on-t01) has the
full first-time setup; each later iteration lists what it adds. In short:

1. Copy `envs/t01.yaml` for your environment and set your dataset names, DB2
   subsystem, CICS names, RACF groups and userids.
2. Put the values that belong to your site, marked `<...>` in
   `envs/<env>.yaml` (LWW's host and port, the Entra tenant and application
   IDs), in `envs/<env>.local.yaml` next to it. That file stays out of git;
   its values replace those of `envs/<env>.yaml`, and rendering stops when a
   placeholder is left. Values of your own (your build libraries `BUILDHLQ`,
   the zmake libraries `LWZMHLQ`, ...) can go there too. `build` and
   `python/deploy.py` read their settings from these files
   ([python/envConfig.py](python/envConfig.py)); both take `--dry-run` to
   print the job instead of submitting it, and the environment from `--env`
   (deploy.py: its second argument) or `$LWD_ENV` (default `t01`). On z/OS,
   the Python venv is `$LWD_VENV`, or else `~/venv`.
3. Define the RACF groups and userids, render the DDL and JCL
   (`python python/deploy.py DEPLOY_DDL`), and run the DDL members in order.
4. Build (`. ./setenv`, then `build`) and deploy (`python python/deploy.py`):
   this copies the load modules and REXX and binds the packages. Then bind the
   plans (`BINDPLAN`) and load `SEEDDATA` and `SETTINGS`.
5. Install the CICS definitions (`CICSCSD`) and the RACF access (`RACF`).
6. Register the API in LWW (`python/processYAML.py`) and upload `LWWAdmin/`
   (`python/uploadLWW.py`).
7. Set up the Entra applications and the certificate of the deploy userid
   ([docs/12-iteration-8.md](docs/12-iteration-8.md#setting-it-up)), try the
   sign-in with `LWDETST`, and schedule `LWDTICK` and `LWDMAIL`.

The scripts in `python/` that talk to LWW read their host and sign-in from
`python/runtimeTargets.yaml`, which stays out of git: copy
[runtimeTargets.example.yaml](python/runtimeTargets.example.yaml) and fill it
in. Passwords are always asked for at run time. Which LWW folder the web UI
and API placeholders go to (`/lwdeploy`, its ID, transaction, default page
and login redirect) and which API spec is registered under which path
prefix is in [python/lwwApp.yaml](python/lwwApp.yaml); a target can
overrule it.

## Testing

`python/testIteration1.py` to `testIteration7.py` walk through the API of each
iteration against a running environment and check the results, from
registering a version to approvals, retries, job output, administration and
notifications. They deploy the demo application of `DDL/SEEDDATA.sql` and ask
for the passphrases of the userids they use. Use `--target <name>` to pick an
entry of `runtimeTargets.yaml`. Each iteration document describes what its
script covers.

The web UI has its own unit tests and a mock backend in
[lwdeploy-frontend](https://github.com/Y-Innovate/lwdeploy-frontend).

## License

Source-available, not open source: you may use the software, run it (also
modified) for others, redistribute it unmodified, and modify it for your own
use, but you may not distribute modified versions. See [LICENSE](LICENSE) for
the exact terms, and [THIRD-PARTY-NOTICES](THIRD-PARTY-NOTICES) for the
open-source components in the built web UI.
