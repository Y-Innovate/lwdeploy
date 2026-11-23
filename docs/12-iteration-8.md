# Iteration 8: the result step signs in with Entra

The result step of every deployment job (S2, `REXX/LWDR916`) no longer signs
in with a PassTicket. It gets an access token from Entra ID with client
credentials, proving who it is with a client assertion: a JWT signed with the
private key of the deploy userid's own certificate in RACF. LWW checks the
Entra token itself and maps the Entra application to the deploy userid, as
it does for the scheduler's tick (iteration 2).

Nothing has been run on z/OS yet.

## Why

A PassTicket is checked against the applid of the CICS region that receives
it. LWW runs in more than one region of a CICSPlex, and `POST /token` is load
balanced across them, so only the region whose applid the ticket was made for
could check it; the others refused it. An Entra token is checked the same way
in every region: its signature, issuer and audience, with nothing tied to an
applid.

A secret for the deploy userid (a client secret, a passphrase) would be
readable by whoever can read the file or the JCL. The certificate's private
key stays in RACF instead: only the deploy userid can use it, through its own
key ring, just as only it could make PassTickets for itself.

## What is built

| Part | What it does |
|---|---|
| `REXX/LWDR916` | The result step: client assertion from JWTSignerUtil (Java, through `BPXWUNIX`), access token from Entra (HWTHTTP), `POST /jobResults` with it. `%LWDR916 TEST` signs in and calls `POST /jobResults` for a run that doesn't exist |
| `LWDM920` | `LWDCONF` gets `TENANT`, `SCOPE`, `CLIENTID`, `JAVAHOME` and `JWTJARS` instead of `APPLID`; no `STEPLIB` any more. Reason `08 91` when the deploy userid has no `DEPLAPP` entry |
| `DDL/SETTINGS` | New settings `TENANT`, `APISCOPE`, `JAVAHOME`, `JWTJARS`, and the `DEPLAPP` entry of the deploy userid; without `LOADLIB` and `LWWAPPL` |
| `JCL/RACF` | Key ring and certificate of the deploy userid, READ on `IRR.DIGTCERT.LISTRING`; without PTKTDATA. The deploy userid stays protected |
| `JCL/LWDETST` | Tries the sign-in under the deploy userid, before any deployment. Replaces `JCL/LWDPTKT` |
| Removed | `LWDA916` (assembler, R_ticketserv), its link-edit deck, `SYS1.CSSLIB` in the build |

JWTSignerUtil lives in its own repository, `jwt_signer`: `JWTSignerUtil
<userid> <keyring> <label> <audience> <applicationId>` prints a signed JWT.
It reads the key ring with the IBMJCEHYBRID provider (`JCEHYBRIDRACFKS`), so
the private key may be in the RACF database or in ICSF.

## The result step

LWDM920 still puts the step into every job three times, under the same `IF`
tests, as `LWDRSA`, `LWDRSO` and `LWDRSH`:

```
//LWDRSO   EXEC PGM=IKJEFT1B,PARM='%LWDR916 000001234 O',REGION=1024M
//SYSEXEC  DD DISP=SHR,DSN=YINCIC.CPSM.T03.LWD.EXEC
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD DUMMY
//LWDCONF  DD *
URL=https://<host>
PORT=<port>
PATH=/lwdeploy/API/v1
KEYRING=*AUTH*/*
TENANT=<tenant ID>
SCOPE=<application ID of the API>/.default
CLIENTID=<application ID of LWDDEPL>
JAVAHOME=/usr/lpp/java/J21.0_64
JWTJARS=/var/lwd/t03/jwt
```

The step then works like this:
1. It takes the userid with `USERID()`, the job name from the TIOT and the JES
   job ID from the SSIB, as before.
2. It runs JWTSignerUtil with `BPXWUNIX`, in a z/OS UNIX process of its own:
   ```
   $JAVAHOME/bin/java -Dstdout.encoding=IBM-1047 -cp '$JWTJARS/*' \
     yinnovate.JWTSignerUtil <userid> <userid> <userid> \
     https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/token <CLIENTID>
   ```
   Key ring and certificate label are both named after the userid. Every jar
   in `JWTJARS` is on the class path, so new versions need no change here.
   The process doesn't inherit the step's environment: `BPXWUNIX` gets
   `JAVA_HOME`, `PATH` and `HOME=/tmp`. `stdout.encoding` makes Java write the
   JWT in EBCDIC, as REXX reads it. The step checks that the last line of the
   output looks like a JWT; otherwise it shows Java's exit status and
   `stderr`. The JVM doesn't start in the default region: the step has
   `REGION=1024M` (found on t03).
3. `POST https://login.microsoftonline.com/<TENANT>/oauth2/v2.0/token` with
   `client_id`, `scope`, `grant_type=client_credentials`,
   `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`
   and `client_assertion`. When Entra can't be reached or answers 429 or 5xx
   it tries again after 2 seconds and once more after 5; the assertion is
   valid for 5 minutes. On any other error it shows Entra's `error` and
   `error_description` (an `AADSTS` code).
4. `POST /jobResults` with the access token, to LWW, as before. A 401 or 403
   gets a hint: the mapping of the Entra application, or the transaction.

| RC | Meaning |
|---|---|
| 0 | Recorded (`TEST`: signed in) |
| 4 | Late result, or recorded already |
| 8 | Not recorded: see `SYSTSPRT`. The run stays `S` until the scheduler marks it stuck after `JOBMINS`; then a deployer retries (D4) |

`LWDR916` never shows the client assertion or the token. TLS to Entra uses
the same key ring as TLS to LWW (`LWDRING`): with `*AUTH*/*` the CA of
Entra's certificate must be in RACF as CERTAUTH (DigiCert Global Root G2 at
the time of writing).

## The client assertion

What JWTSignerUtil puts in it:

| Part | Value |
|---|---|
| Header | `alg` `RS256`, `kid` the label, `x5t#S256` the SHA-256 thumbprint of the certificate |
| `iss`, `sub` | The client ID of the deploy userid's Entra application |
| `aud` | The token URL of the tenant |
| `iat`, `exp` | Now, and 5 minutes later |

Entra's documentation describes `PS256` and asks for `jti` and `nbf` as well;
Entra accepted the assertion without them when tried by hand with
`python/getAccessToken.sh`. Should Entra start refusing it (`AADSTS` codes
about the assertion), adding a random `jti` and `nbf` in `JWTSigner` is the
first thing to try.

## Configuration

New in `envs/<env>.yaml`:

| Key | t03 | What it is |
|---|---|---|
| `ENTRATENANT` | `<tenant ID>` | Entra tenant; setting `TENANT` |
| `LWDAPISCOPE` | `<application ID of the API>/.default` | Scope of LWD's API: its application ID with `/.default`; setting `APISCOPE` |
| `DEPLOYAPPID` | `<application ID of LWDDEPL>` | Entra application of `DEPLOYUSER`, which LWW maps to it; `DEPLAPP` entry |
| `JAVAHOME` | `/usr/lpp/java/J21.0_64` | Java 21 or later; setting `JAVAHOME` |
| `JWTJARS` | `/var/lwd/t03/jwt` | Directory with the jars of JWTSignerUtil; setting `JWTJARS` |

`LWWAPPLID` is gone. The tenant, the scope and the application belong to the
site: the tracked `envs/<env>.yaml` has placeholders, and the real values go
in `envs/<env>.local.yaml`, which stays out of git (see the README).

`DEPLAPP` is a REFTABLES list: key the deploy userid, value its client ID.
`DDL/SETTINGS` writes the entry of `DEPLOYUSER`; for every other userid in
`DEPLUSER`, insert one the same way. Like the security and location
settings, it can't be changed through the API: a wrong client ID only makes
the sign-in fail, but it belongs with the RACF and Entra setup it has to
match. The new settings can't be changed through the API either (`LWDM001`
only allows the timing and job keys).

## Setting it up

For t03; for t01 the same with its own values.

1. **Entra:** an application registration for the deploy userid (its ID
   goes in `DEPLOYAPPID`), with permission on LWD's API (`LWDAPISCOPE`) as the
   scheduler's application has. One application per deploy userid, as LWW
   maps one application to one userid.
2. **LWW:** map that application to `LWDDEPL`. LWW checks both its own and
   Entra tokens on every path, so `/jobResults` needs nothing else.
3. **`envs/t03.yaml` and `envs/t03.local.yaml`:** check the values above.
4. **The jars:** build `jwt_signer` and copy the three jars that
   `python/getAccessToken.sh` uses into one directory, `JWTJARS`, readable by
   every deploy userid. Only these three: every jar in the directory is on
   the class path, and `ibm.semeru-zjavasecurity` comes with the JDK.
   ```
   T=<your clone of jwt_signer>/util/target
   mkdir -p /var/lwd/t03/jwt
   cp $T/yinnovate-jwt-signer-util-1.0.0.jar \
      $T/dependency/yinnovate-jwt-signer-1.0.0.jar \
      $T/dependency/nimbus-jose-jwt-9.37.jar /var/lwd/t03/jwt
   chmod 755 /var/lwd/t03/jwt; chmod 644 /var/lwd/t03/jwt/*.jar
   ```
5. **RACF:** submit `RACF` again. New:
   - Key ring `LWDDEPL` of `LWDDEPL`, and a self-signed certificate with label
     `LWDDEPL` (RSA 2048, 2 years) connected to it as its default, each only
     when it isn't there. A certificate made by hand stays as it is
   - READ on FACILITY `IRR.DIGTCERT.LISTRING` for `LWDDEPL`: it lets a userid
     read its own key rings, private keys included
   - PTKTDATA is no longer touched. The profiles `IRRPTAUTH.<applid>.LWDDEPL`
     can be deleted by hand once no job of before this iteration runs

   The submitter needs authority for `RACDCERT` for other userids.
6. **The certificate in Entra:** export it, without the key, and upload it
   to the application under *Certificates & secrets*:
   ```
   RACDCERT ID(LWDDEPL) EXPORT(LABEL('LWDDEPL')) DSN('<you>.LWDDEPL.CER') FORMAT(CERTB64)
   ```
   Download the data set as text and upload it as a `.cer` file.
7. **DDL:** `python python/deploy.py DEPLOY_DDL t03`, then run `SETTINGS`
   with `RUNDDL`.
8. **Build and deploy:** `. ./setenv`, `build`, then
   `python python/deploy.py DEPLOY_ALL t03`. Changed: `LWDM920`, `LWDM916`
   (comment only), `REXX/LWDR916`. NEWCOPY `LWDM920` in CICS.
9. **Try the sign-in:** give yourself READ on SURROGAT `LWDDEPL.SUBMIT`,
   submit `LWDETST`, and read `SYSTSPRT`. RC 0 means Java, the key ring,
   Entra, the mapping in LWW and the transaction `LWDJ` work: LWD answered
   404 for run 999999999. Take the permission away again.
10. **The passphrase of iteration 4:** once no job of before this iteration
    runs, make the deploy userid protected again, so nobody can sign on
    with it and wrong attempts can't revoke it:
    ```
    ALU LWDDEPL NOPASSWORD
    ```

## Execution node

A job that runs on another JES2 node (`EXECNODE`) needs there what the
result step needs here: Java at `JAVAHOME`, the jars at `JWTJARS`, the key
ring and certificate of the deploy userid (the same certificate, when the
RACF databases differ, or another one uploaded to the same Entra
application), `IRR.DIGTCERT.LISTRING`, and a way out to
`login.microsoftonline.com`. PTKTDATA isn't needed there any more.

## Renewing the certificate

The certificate of `RACF` is valid for 2 years. Before it ends: make a new
one with another label, upload it to the Entra application next to the old
one, then connect it to the key ring as default under label `LWDDEPL`
(rename the old one first with `RACDCERT ID(LWDDEPL) ALTER(LABEL('LWDDEPL'))
NEWLABEL('LWDDEPL-OLD')`). Delete the old one in Entra and RACF afterwards.
No deployment fails in between.

## To check on the first run

- **`BPXWUNIX` in a TSO batch step:** it should need nothing more than the
  OMVS segment. If the step says the function isn't found, add
  `SYS1.SBPXEXEC` to `SYSEXEC` (LWDM920 `R510`).
- **Java in that process:** startup time (a few seconds per result step),
  and whether `-Dstdout.encoding=IBM-1047` is right:
  if the step says the output is not a JWT, Java wrote something else.
- **TLS to Entra with HWTHTTP:** the CA in RACF as CERTAUTH, a way out to the
  internet (or a proxy, which the step doesn't set yet), and whether Entra
  needs SNI from the toolkit.
- **Entra's answer:** `AADSTS700027` means the certificate in the assertion
  isn't the one uploaded to the application; `AADSTS7000215` and the like
  that the client ID or scope don't match.
- **The scheduler's tick** could sign in the same way, without its client
  secret: only `getToken()` in `tick.py` changes. Not done in this iteration.
