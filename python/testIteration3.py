# Walks through "Trying it" in docs/07-iteration-3.md: job output (S3, M4).
# Deploys V1.0.0 to DEV and waits until the scheduled LWDTICK job has
# collected the output of its runs, then reads the steps, the spool files and
# the text of every file through GET /jobSteps, /spoolFiles and /spoolText,
# paging and decoding. Then deploys V1.0.1-BAD, whose job 2 ends with RC 8,
# checks the step and job return codes of that run, and cancels it to free DEV.
#
#   python testIteration3.py
#
# Needs the deployer of testIteration2.py (demo access and owner groups) and a
# scheduled LWDTICK: the collector runs in that job, not in POST
# /schedulerTicks, so there is nothing to call. Every run submits real jobs
# under the deploy userid.
import base64
import json
import requests
import time

from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

# From DDL/SEEDDATA.sql: job 1 runs IEBGENER in step SHOW, job 2 IDCAMS in
# step SETRC with SET MAXCC = DEMORC: 0 for V1.0.0, 8 for V1.0.1-BAD
appCode = "DEMO"
goodVersion = "V1.0.0"
badVersion = "V1.0.1-BAD"

pollSeconds = 5
pollMax = 60
# How long to wait for LWDTICK to collect the output
collectWaitMinutes = 20

userid = None
passphrase = None


def step(text):
    print(f"\n=== {text}")


def check(condition, text):
    if not condition:
        raise Exception(f'check failed: {text}')

    print(f"OK: {text}")


def s(value):
    # LWW returns an empty variable-length field as null
    return (value or "").strip()


def signIn():
    # The token goes on the session only, as in testIteration2.py: call() is
    # the only place that retries
    Globals.s.headers.pop('Authorization', None)
    Globals.myCreds = (userid, passphrase)
    MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")
    Globals.myCreds = None
    Globals.s.headers['Authorization'] = f"Bearer {Globals.myBearer}"
    Globals.myBearer = ""


def call(method, uri, data=None, okCodes=(200,), quiet=False):
    for attempt in range(0, 2):
        resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)
        if not quiet or resp.status_code not in okCodes:
            print(f"{method.upper()} {uri}: {resp.status_code} {resp.text[:300]}")

        if (resp.status_code != 401 or attempt > 0):
            break

        print("Signing in again")
        signIn()

    if (resp.status_code not in okCodes):
        raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    return json.loads(resp.text) if resp.text else {}


def find(rows, field, value):
    for row in rows:
        if (s(row[field]) == value):
            return row

    raise Exception(f'{field} {value} not found')


def deploy(app, env, version, note, expect):
    data = {'appID': app, 'envID': env, 'versionID': version, 'requestNote': note}
    d = call("post", "/deployments", data, (201,))
    check(s(d['deplStatus']) == expect,
          f"deployment {d['deplID']} is {expect}, it is {s(d['deplStatus'])}")
    return d['deplID']


def waitWhile(deplID, statuses):
    st = ''
    for i in range(0, pollMax):
        st = s(call("get", f"/deployments/{deplID}", quiet=True)['deplStatus'])

        if (st not in statuses):
            break

        time.sleep(pollSeconds)

    return st


def lastRun(deplID, jobNo):
    runs = call("get", f"/jobRuns?deplID={deplID}&jobNo={jobNo}", quiet=True)['runs']
    check(len(runs) > 0, f"job {jobNo} of {deplID} has a run")
    return runs[0]


def waitForOutput(deplID, jobNos):
    # The runs' outputStatus goes from W to C when LWDTICK has collected them
    print(f"Waiting for LWDTICK to collect the output (up to {collectWaitMinutes} minutes)")
    runs = {}
    for i in range(0, collectWaitMinutes * 2):
        runs = {j: lastRun(deplID, j) for j in jobNos}
        states = {j: s(r['outputStatus']) for j, r in runs.items()}

        if all(st != 'W' for st in states.values()):
            break

        time.sleep(30)

    for j, r in runs.items():
        check(s(r['outputStatus']) == 'C',
              f"output of run {r['runID']} (job {j}) collected, outputStatus "
              f"{s(r['outputStatus'])}")
    return runs


def allSteps(runID):
    steps, since = [], 0
    while True:
        page = call("get", f"/jobSteps?runID={runID}&stepNo_since={since}")['steps']
        steps += page
        if len(page) < 20:
            return steps
        since = page[-1]['stepNo']


def allFiles(runID):
    files, since = [], 0
    while True:
        page = call("get", f"/spoolFiles?runID={runID}&fileNo_since={since}")['spoolFiles']
        files += page
        if len(page) < 20:
            return files
        since = page[-1]['fileNo']


def fileText(runID, fileNo):
    # All lines of one file, page by page
    lines, since, pages = [], 0, 0
    while True:
        t = call("get", f"/spoolText/{runID}?fileNo={fileNo}&lineNum_since={since}",
                 quiet=True)
        pages += 1
        text = base64.b64decode(s(t['spoolText'])).decode('utf-8') if t['lineCount'] else ''
        part = text.split('\n')[:-1] if text else []
        check(len(part) == t['lineCount'],
              f"file {fileNo} part {pages}: {t['lineCount']} lines from line "
              f"{t['firstLineNum']}")
        check(t['lineCount'] == 0 or t['firstLineNum'] == since + 1,
              "the part starts right after lineNum_since")
        lines += part
        if s(t['moreLines']) != 'Y':
            return lines, pages
        since = t['firstLineNum'] + t['lineCount'] - 1


def showRun(run, label):
    runID = run['runID']
    step(f"{label}: run {runID}, job name {s(run['jobName'])}, "
         f"JES {s(run['jesJobID'])}, jobRC {run['jobRC']}")

    steps = allSteps(runID)
    for st in steps:
        print(f"  step {st['stepNo']:3} {s(st['stepName']):8} {s(st['procStep']):8} "
              f"RC {st['stepRC']:4} {s(st['abendCode']):5} flushed {s(st['flushed'])}")

    files = allFiles(runID)
    for f in files:
        print(f"  file {f['fileNo']:3} {s(f['ddName']):8} {s(f['stepName']):8} "
              f"{s(f['procStep']):8} {f['lineCount']:6} lines, truncated "
              f"{s(f['truncated'])}")

    ddnames = [s(f['ddName']) for f in files]
    check(ddnames[:3] == ['JESMSGLG', 'JESJCL', 'JESYSMSG'],
          "the first three files are JESMSGLG, JESJCL and JESYSMSG")

    for f in files:
        lines, pages = fileText(runID, f['fileNo'])
        check(len(lines) == f['lineCount'],
              f"{s(f['ddName'])}: {len(lines)} lines in {pages} part(s), as listed")

    msglg, _ = fileText(runID, 1)
    check(any(s(run['jobName']) in l for l in msglg),
          "JESMSGLG mentions the job name")
    return steps


def doStuff():
    global userid, passphrase
    userid = input("Deployer userid: ").strip().upper()
    passphrase = getpass(f"Passphrase of {userid}: ")

    step("1. Sign in; the demo application, DEV and both versions")
    signIn()
    app = find(call("get", "/applications")['applications'], 'appCode', appCode)['appID']
    envs = call("get", f"/environments?appID={app}")['environments']
    dev = find(envs, 'envCode', 'DEV')
    check(not dev['activeDeplID'],
          "DEV is free" if not dev['activeDeplID']
          else f"DEV is held by {dev['activeDeplID']}: POST /cancellations/{{deplID}}")
    dev = dev['envID']
    versions = call("get", f"/versions?appID={app}")['versions']
    good = find(versions, 'versionName', goodVersion)['versionID']
    bad = find(versions, 'versionName', badVersion)['versionID']

    step(f"2. {goodVersion} to DEV, then wait for its output")
    d = deploy(app, dev, good, 'testIteration3: output', 'U')
    check(waitWhile(d, ('U',)) == 'S', f"deployment {d} succeeded")
    runs = waitForOutput(d, (1, 2))

    steps = showRun(runs[1], "3. Job 1")
    show = find(steps, 'stepName', 'SHOW')
    check(show['stepRC'] == 0 and s(show['flushed']) == 'N', "step SHOW ran with RC 0")
    check(any(s(st['stepName']) == 'LWDRSO' and s(st['flushed']) == 'N' for st in steps),
          "the result step LWDRSO ran")
    check(all(s(st['flushed']) == 'Y' for st in steps
              if s(st['stepName']) in ('LWDRSA', 'LWDRSH')),
          "LWDRSA and LWDRSH did not run")
    check(runs[1]['jobRC'] == 0, "job RC 0")

    steps = showRun(runs[2], "4. Job 2")
    check(find(steps, 'stepName', 'SETRC')['stepRC'] == 0, "step SETRC ran with RC 0")

    step("5. Not there: a spool file that doesn't exist")
    r = call("get", f"/spoolText/{runs[1]['runID']}?fileNo=999", okCodes=(404,))
    check(s(r.get('reasonCode')) == '01', "404 with reason 01")

    step(f"6. {badVersion} to DEV: job 2 ends with RC 8")
    d = deploy(app, dev, bad, 'testIteration3: RC 8', 'U')
    check(waitWhile(d, ('U',)) == 'F', f"deployment {d} failed")
    runs = waitForOutput(d, (2,))
    steps = showRun(runs[2], "7. Job 2 of the failed deployment")
    check(find(steps, 'stepName', 'SETRC')['stepRC'] == 8, "step SETRC ended with RC 8")
    check(any(s(st['stepName']) == 'LWDRSH' and s(st['flushed']) == 'N' for st in steps),
          "the result step LWDRSH ran")
    check(runs[2]['jobRC'] == 8, "job RC 8")

    step("8. Cancel it, so DEV is free again")
    c = call("post", f"/cancellations/{d}", {'commentText': 'testIteration3 done'})
    check(s(c['deplStatus']) == 'C', f"{d} cancelled")

    print("\nDone.")


doStuff()
