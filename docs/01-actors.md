# Actors

Who and what interacts with the LWD deployment application, how each is
identified, and what each may do. Use case IDs refer to
[02-use-cases.md](02-use-cases.md).

## People

| Actor | Identified by | Goal | Use cases |
|---|---|---|---|
| Member | RACF userid in the application's access group | See applications, what is deployed where, history and job output | U1, U2, M1-M4 |
| Deployer | A member who is also in the environment's deployer group, if the environment has one | Get a version into an environment | D1-D4, plus all member use cases |
| Approver | RACF userid in the environment's approver group | Allow or stop deployments into that environment | AP1, AP2 |
| Application owner | RACF userid in the application's owner group | Keep environments, jobs, variables and versions in order | O1-O4 |
| CI pipeline | Service RACF userid in the owner group, token from `POST /token` | Register a version after a build | O4 |
| Administrator | RACF userid with access to a FACILITY resource | Set up applications, groups, deploy userids, environment controls and settings | A1-A5 |

Notes:

- **Roles are relationships, not account types.** One RACF userid can be a
  member of one application, owner of another and approver for a third
  application's PRD. Every role is decided per application or per environment,
  from the RACF groups the userid is in.
- **"In a group" means READ access to the group's FACILITY profile.** Each
  RACF group LWD uses has a profile `LWD.<env>.GRP.<group>` with that group on
  its access list. LWD checks the profile with `QUERY SECURITY`; it never reads
  group connections itself (decision M7).
- **Deployer is a member by default.** Every member of the application can
  deploy, unless the environment names a deployer group. Then only members who
  are also in that group can deploy there.
- **Approvers don't need to be members.** Being in an environment's approver
  group is enough to see the requests for that environment, and the application,
  versions and job output they concern.
- **Owners don't automatically deploy or approve.** An owner who wants to deploy
  needs to be a member, and in the deployer group if there is one. An owner can
  be an approver, but never for their own request.
- **The CI pipeline is an owner.** It is listed apart because it calls the API
  without the UI. In v1 it has the same rights as any owner, but should only use
  O4.
- **Administrators set the security-relevant controls.** Owners maintain their
  application's environments, jobs and variables, but the deploy userid, the
  approval rules and the deployer group of an environment are set by an
  administrator. This way an owner can't switch off approval for production.
- **An administrator is not automatically a member.** Administrators see all
  applications and deployments (A4), but to deploy they need to be a member like
  anyone else.

## Systems

| Actor | Role | Use cases |
|---|---|---|
| LWD backend (CICS) | Validates and records everything; starts deployments | All |
| Submit task (CICS) | Submits every job of a deployment to `INTRDR` under the environment's deploy userid | S1 |
| Deployment job (z/OS batch) | Does the actual work, under the deploy userid | S1, S2 |
| Result step | Last step of every deployment job; sends how the job ended to `POST /jobResults`, signed in as the deploy userid with an Entra access token | S2 |
| Output collector (batch, in LWDTICK) | Copies the output of ended deployment jobs from JES with SDSF and stores it in DB2 | S3 |
| Scheduled batch | Starts deployments that are due, finds stuck jobs, expires requests, purges old output, refreshes email addresses from RACF | S4 |
| Mail | Delivers notification emails (CSSMTP, to be confirmed) | S5 |
| RACF | Holds userids, groups and email addresses (`WAEMAIL`); checks passwords; controls surrogate access | U1, S4, all access checks |
| JES | Runs the jobs and holds their output | S1-S3 |
| Entra ID | Signs users in through LWW's SSO redirect | U1 |
| LWW gateway | Maps JSON to copybooks; hosts the UI; issues tokens through `POST /token` | All API calls |

## What each actor can do

| Capability | Member | Deployer | Approver | Owner | Admin |
|---|---|---|---|---|---|
| Maintain own notification settings | Yes | Yes | Yes | Yes | Yes |
| See the application, environments, inventory, versions | Own apps | Own apps | Apps with requests to approve | Own apps | All |
| See deployment history, frozen JCL and job output | Own apps | Own apps | Apps with requests to approve | Own apps | All |
| Request a deployment, cancel it, retry or resume it | - | Allowed environments | - | - | - |
| Approve or reject a request | - | - | Own environments, not own requests | - | - |
| Maintain environments: name, order, variables, promotion gate | - | - | - | Own apps | - |
| Maintain job templates and application variables | - | - | - | Own apps | - |
| Register, edit and retire versions | - | - | - | Own apps | - |
| Create and delete applications; set access and owner group | - | - | - | - | Yes |
| Set environment controls: deploy userid, approval, deployer group | - | - | - | - | Yes |
| Maintain the RACF group and deploy userid allowlists | - | - | - | - | Yes |
| Change settings | - | - | - | - | Yes |

"Own apps" means applications whose access group (member, deployer) or owner
group (owner) the userid is in.

## How identity reaches the backend

| Actor | Route | Userid CICS runs under |
|---|---|---|
| Any person, RACF sign-in | Browser -> LWW login page -> LWW | The person's RACF userid |
| Any person, Entra sign-in | Browser -> LWW SSO redirect -> Entra -> LWW | The RACF userid mapped from Entra |
| CI pipeline | `POST /token` with the service userid and passphrase, then API calls with the token | The service userid |
| Submit task | Started by the backend, checks a deployment token | A submit userid; only this one has surrogate access to the deploy userids |
| Deployment job | JES | The environment's deploy userid |
| Result step | Entra client credentials with a client assertion signed by the deploy userid's certificate, then `POST /jobResults` with the access token (iteration 8) | The deploy userid, mapped from its Entra application, under its own transaction |
| Scheduled batch with the output collector | JES, as a scheduled job | The scheduler's userid |

There is no anonymous access. The backend always takes the user from the CICS
userid, never from the request, and decides each role from the groups that
userid is in.

## Deployment lifecycle

```
                         approval needed
 REQUESTED --------------------------------> AWAITING_APPROVAL
     |                                         |    |    |
     | no approval needed                N approvals |    | time limit
     |                                         |  1 rejection   passed
     v                                         v    v    v
  QUEUED <------------------------------------+  REJECTED  EXPIRED
     |
     | time reached and environment free
     v
  RUNNING ---- all jobs within highest RC ----> SUCCEEDED
     |   ^
     |   | retry / resume
     v   |
   FAILED

 REQUESTED, AWAITING_APPROVAL, QUEUED, FAILED, and RUNNING between jobs
     ----- cancel -----> CANCELLED
```

- `QUEUED` covers both "scheduled for later" and "waiting for the environment":
  only one deployment per environment is `RUNNING` at a time.
- A deployment that is approved after its scheduled time starts as soon as the
  environment is free.
- `FAILED` is not final: a deployer can retry the failed job or resume from it
  (D4) until the deployment is cancelled.
- Only `SUCCEEDED` changes the inventory.
