# Walks through "Trying it" in docs/05-iteration-1.md: register a version as
# CI would, deploy it to DEV and TST, see the promotion gate stop a new version,
# a failing deployment and its cancellation, and a PRD request that waits for
# approval. The userid needs READ on the FACILITY profiles of the demo access
# and owner groups. Every run submits real jobs under the deploy userid.
import base64
import json
import requests
import time

from datetime import datetime
from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

# From DDL/SEEDDATA.sql
appCode = "DEMO"
goodVersion = "V1.0.0"
badVersion = "V1.0.1-BAD"

pollSeconds = 5
pollMax = 60

def step(text):
    print(f"\n=== {text}")

def getToken():
    # The token goes on the session only. With Globals.myBearer set, MyRequests
    # would itself get a new token and send the request again after every 4xx
    # but 404: the 409s this test expects would be sent twice, and call() would
    # never see a first 401. So call() is the only place that retries.
    Globals.s.headers.pop('Authorization', None)
    Globals.myCreds = (Globals.tokenData['username'], Globals.tokenData['password'])
    MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")
    Globals.myCreds = None
    Globals.s.headers['Authorization'] = f"Bearer {Globals.myBearer}"
    Globals.myBearer = ""

def call(method, uri, data=None, okCodes=(200,)):
    for attempt in range(0, 2):
        resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)
        print(f"{method.upper()} {uri}: {resp.status_code} {resp.text[:400]}")

        if (resp.status_code != 401 or attempt > 0):
            break

        print("Retrying with a new token")
        getToken()

    if (resp.status_code not in okCodes):
        raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    return json.loads(resp.text)

def check(condition, text):
    if not condition:
        raise Exception(f'check failed: {text}')

    print(f"OK: {text}")

def s(value):
    # LWW returns an empty variable-length field as null
    return (value or "").strip()

def find(rows, field, value):
    for row in rows:
        if (s(row[field]) == value):
            return row

    raise Exception(f'{field} {value} not found')

def deploy(appID, envID, versionID, note, expect='U'):
    data = {}
    data['appID'] = appID
    data['envID'] = envID
    data['versionID'] = versionID
    data['requestNote'] = note
    d = call("post", "/deployments", data, (201,))
    # Q means the environment is held by another deployment: nothing starts
    # it later until the scheduler of iteration 2 exists
    check(s(d['deplStatus']) == expect,
          f"deployment {d['deplID']} is {expect}, it is {s(d['deplStatus'])}")
    return d

def checkFree(envs):
    # A deployment left failed (F) or running by an earlier run holds its
    # environment: cancel it first, POST /cancellations/{deplID}
    held = [f"{s(e['envCode'])} by deployment {e['activeDeplID']}"
            for e in envs if e['activeDeplID']]
    check(not held, "DEV, TST and PRD are free" if not held
          else f"held: {', '.join(held)}")

def waitUntilEnded(deplID):
    status = ''

    for i in range(0, pollMax):
        status = s(call("get", f"/deployments/{deplID}")['deplStatus'])

        if (status not in ('Q', 'U')):
            break

        time.sleep(pollSeconds)

    return status

def doStuff():
    userid = input("RACF userid: ").strip().upper()
    passphrase = getpass(f"Passphrase of {userid}: ")

    step(f"1. POST /token as {userid}, then GET /me")
    Globals.tokenData = {'username': userid, 'password': passphrase}
    getToken()
    me = call("get", "/me")
    check(s(me['userID']) == userid, "GET /me returns the userid")

    step("2. GET /applications, /environments and /versions")
    app = find(call("get", "/applications")['applications'], 'appCode', appCode)
    appID = app['appID']
    check(s(app['isMember']) == 'Y' and s(app['isOwner']) == 'Y',
          f"{appCode} is application {appID}; member and owner")
    envs = call("get", f"/environments?appID={appID}")['environments']
    dev = find(envs, 'envCode', 'DEV')
    tst = find(envs, 'envCode', 'TST')
    prd = find(envs, 'envCode', 'PRD')
    check(s(dev['canDeploy']) == 'Y', "DEV can be deployed to")
    checkFree((dev, tst, prd))
    versions = call("get", f"/versions?appID={appID}")['versions']
    good = find(versions, 'versionName', goodVersion)
    bad = find(versions, 'versionName', badVersion)

    step("3. POST /versions, as the CI pipeline would")
    newName = f"V1.1.{datetime.now():%y%m%d%H%M%S}"
    data = {'appID': appID, 'versionName': newName, 'locType': 'D',
            'location': f"LWDDEPL.DEMO.{newName.replace('.', '')[-8:]}",
            'versionDescription': 'Registered by testIteration1.py'}
    new = call("post", "/versions", data, (201,))
    check(s(new['isUsed']) == 'N', f"{newName} is version {new['versionID']}")
    call("post", "/versions", data, (409,))
    print("OK: the same name again is a 409")

    step(f"4. Deploy {goodVersion} to DEV and wait until it has ended")
    d = deploy(appID, dev['envID'], good['versionID'], 'testIteration1: good to DEV')
    status = waitUntilEnded(d['deplID'])
    check(status == 'S', f"deployment {d['deplID']} succeeded, it is {status}")
    jobs = call("get", f"/deploymentJobs?deplID={d['deplID']}")['jobs']
    check(all(s(j['jobStatus']) == 'D' for j in jobs), f"all {len(jobs)} jobs are done")
    jcl = call("get", f"/deploymentJcl/{d['deplID']}?jobNo=1")
    text = base64.b64decode(s(jcl['jcl'])).decode('utf-8')
    print(text)
    check(goodVersion in text, "the frozen JCL holds the version name")
    dev = find(call("get", f"/environments?appID={appID}")['environments'], 'envCode', 'DEV')
    check(s(dev['currentVersionName']) == goodVersion and s(dev['envState']) == 'O',
          f"the inventory has {goodVersion} in DEV")

    step(f"5. The promotion gate: {newName} never ran in DEV, so not to TST")
    call("post", "/deployments", {'appID': appID, 'envID': tst['envID'],
                                  'versionID': new['versionID']}, (409,))
    print("OK: 409, the gate holds")

    step(f"6. Deploy {goodVersion} to TST: it passed DEV")
    d = deploy(appID, tst['envID'], good['versionID'], 'testIteration1: good to TST')
    status = waitUntilEnded(d['deplID'])
    check(status == 'S', f"deployment {d['deplID']} succeeded, it is {status}")

    step(f"7. Deploy {badVersion} to DEV: job 2 ends with RC 8")
    d = deploy(appID, dev['envID'], bad['versionID'], 'testIteration1: bad to DEV')
    status = waitUntilEnded(d['deplID'])
    check(status == 'F', f"deployment {d['deplID']} failed, it is {status}")
    jobs = call("get", f"/deploymentJobs?deplID={d['deplID']}")['jobs']
    check(s(jobs[1]['jobStatus']) == 'F' and s(jobs[1]['jobResult']) == 'H',
          "job 2 failed above its highest RC")
    dev = find(call("get", f"/environments?appID={appID}")['environments'], 'envCode', 'DEV')
    check(dev['activeDeplID'] == d['deplID'] and s(dev['envState']) == 'H',
          "DEV is held by the failed deployment, possibly half deployed")
    check(s(call("get", f"/deployments/{d['deplID']}")['canCancel']) == 'Y', "it can be cancelled")
    c = call("post", f"/cancellations/{d['deplID']}", {'commentText': 'Test over'})
    check(s(c['deplStatus']) == 'C', "cancelled")
    dev = find(call("get", f"/environments?appID={appID}")['environments'], 'envCode', 'DEV')
    check(dev['activeDeplID'] == 0, "DEV is free again")

    step(f"8. Deploy {goodVersion} to PRD: it waits for approval")
    d = deploy(appID, prd['envID'], good['versionID'], 'testIteration1: to PRD', 'W')
    check(s(d['deplStatus']) == 'W', "the deployment waits for approval (W)")
    c = call("post", f"/cancellations/{d['deplID']}", {'commentText': 'Approval comes in iteration 2'})
    check(s(c['deplStatus']) == 'C', "cancelled, as approval isn't built yet")

    print(f"\nDone. DEV and TST run {goodVersion}; {newName} is registered.")

doStuff()
