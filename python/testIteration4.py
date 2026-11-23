# Walks through "Trying it" in docs/08-iteration-4.md: the result step over
# REST. Deploys V1.0.0 to DEV: both jobs must end through POST /jobResults
# (REXX LWDR916, signed in with a PassTicket of the deploy userid), and job 2
# must have been submitted by the CICS submit task, which LWD now uses for
# every job. Then checks that a user can't send a result, deploys V1.0.1-BAD,
# whose job 2 ends above its highest RC, and cancels it to free DEV.
#
#   python testIteration4.py
#
# Needs the deployer of testIteration2.py and a scheduled LWDTICK (iteration
# 3), and the PassTicket setup of docs/08-iteration-4.md: try JCL/LWDPTKT
# first. Every run submits real jobs under the deploy userid.
import json
import requests
import time

from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

appCode = "DEMO"
goodVersion = "V1.0.0"
badVersion = "V1.0.1-BAD"

pollSeconds = 5
pollMax = 60

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

        if (resp.status_code != 401 or attempt > 0 or 401 in okCodes):
            break

        print("Signing in again")
        signIn()

    if (resp.status_code not in okCodes):
        raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    try:
        return resp.status_code, (json.loads(resp.text) if resp.text else {})
    except ValueError:
        # CICS or LWW itself may refuse with a page that isn't JSON
        return resp.status_code, {}


def get(uri, quiet=False):
    return call("get", uri, quiet=quiet)[1]


def find(rows, field, value):
    for row in rows:
        if (s(row[field]) == value):
            return row

    raise Exception(f'{field} {value} not found')


def deploy(app, env, version, note):
    data = {'appID': app, 'envID': env, 'versionID': version, 'requestNote': note}
    d = call("post", "/deployments", data, (201,))[1]
    check(s(d['deplStatus']) == 'U',
          f"deployment {d['deplID']} is running, it is {s(d['deplStatus'])}")
    return d['deplID']


def waitWhile(deplID, statuses):
    st = ''
    for i in range(0, pollMax):
        st = s(get(f"/deployments/{deplID}", quiet=True)['deplStatus'])

        if (st not in statuses):
            break

        time.sleep(pollSeconds)

    return st


def lastRun(deplID, jobNo, required=True):
    runs = get(f"/jobRuns?deplID={deplID}&jobNo={jobNo}", quiet=True)['runs']
    if not required and not runs:
        print(f"  job {jobNo}: no run")
        return None
    check(len(runs) > 0, f"job {jobNo} of {deplID} has a run")
    return runs[0]


def explain(run):
    # Where a deployment stuck in U went wrong, from its last run
    st = s(run['runStatus'])
    if st == 'S':
        print(f"  Run {run['runID']} ({s(run['jobName'])}) has no result yet. Is the "
              "job still running or waiting in JES? If it has ended, read SYSTSPRT "
              "of step LWDRSO: LWDR916 didn't get POST /jobResults through")
    elif st == 'N':
        print(f"  Run {run['runID']} was never submitted: the submit task didn't "
              "start or failed; see the CICS log (LWDC910, START ERROR)")


def showRun(run, jobNo):
    print(f"  job {jobNo}: run {run['runID']} {s(run['jobName'])} "
          f"JES {s(run['jesJobID'])} status {s(run['runStatus'])} "
          f"result {s(run['jobResult'])} message {s(run['jobMessage'])}")


def doStuff():
    global userid, passphrase
    userid = input("Deployer userid: ").strip().upper()
    passphrase = getpass(f"Passphrase of {userid}: ")

    step("1. Sign in; the demo application, DEV and both versions")
    signIn()
    app = find(get("/applications")['applications'], 'appCode', appCode)['appID']
    dev = find(get(f"/environments?appID={app}")['environments'], 'envCode', 'DEV')
    check(not dev['activeDeplID'],
          "DEV is free" if not dev['activeDeplID']
          else f"DEV is held by {dev['activeDeplID']}: POST /cancellations/{{deplID}}")
    dev = dev['envID']
    versions = get(f"/versions?appID={app}")['versions']
    good = find(versions, 'versionName', goodVersion)['versionID']
    bad = find(versions, 'versionName', badVersion)['versionID']

    step(f"2. {goodVersion} to DEV: both results over REST")
    d = deploy(app, dev, good, 'testIteration4: result over REST')
    st = waitWhile(d, ('U',))
    runs = {j: lastRun(d, j, required=False) for j in (1, 2)}
    for j, r in runs.items():
        if r:
            showRun(r, j)
    if st != 'S':
        last = runs[2] or runs[1]
        if last:
            explain(last)
    check(st == 'S', f"deployment {d} succeeded (S), it is {st}")
    for j, r in runs.items():
        check(s(r['runStatus']) == 'E' and s(r['jobResult']) == 'O',
              f"run of job {j} ended within its highest RC")
        check(s(r['jesJobID']) != '', f"run of job {j} has the JES job ID that "
              "LWDR916 sent")

    step("3. A user can't send a result")
    code, r = call("post", "/jobResults",
                   {'runID': runs[1]['runID'], 'jobName': s(runs[1]['jobName']),
                    'jesJobID': s(runs[1]['jesJobID']), 'jobResult': 'O'},
                   okCodes=(401, 403))
    check(code in (401, 403), f"POST /jobResults as {userid}: {code}, refused "
          "(transaction or deploy userid)")

    step(f"4. {badVersion} to DEV: job 2 ends above its highest RC")
    d = deploy(app, dev, bad, 'testIteration4: RC 8')
    st = waitWhile(d, ('U',))
    r = lastRun(d, 2, required=False) or lastRun(d, 1)
    showRun(r, 2 if r['jobNo'] == 2 else 1)
    if st == 'U':
        explain(r)
    check(st == 'F', f"deployment {d} failed (F), it is {st}")
    check(s(r['runStatus']) == 'E' and s(r['jobResult']) == 'H',
          "run of job 2 ended above its highest RC (H)")

    step("5. Cancel it, so DEV is free again")
    c = call("post", f"/cancellations/{d}", {'commentText': 'testIteration4 done'})[1]
    check(s(c['deplStatus']) == 'C', f"{d} cancelled")

    print("\nDone.")


doStuff()
