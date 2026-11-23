# Tests the two paths iteration 5 adds for the web UI, without the UI
# (docs/09-iteration-5.md): GET /applications/{appID} (LWDM304) and
# GET /deployments (LWDM211) with its rules for which rows a user sees.
# Reads only: no deployment is requested.
#
#   python testIteration5.py
#
# Needs the deployer of testIteration2.py, who is a member of DEMO and has
# requested deployments there in earlier iterations. Optionally a second
# userid that is only an approver of DEMO (in the approver group of PRD, not
# in its access or owner group): it must see only the deployments it decided.
import json
import requests

from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

appCode = "DEMO"


def step(text):
    print(f"\n=== {text}")


def check(condition, text):
    if not condition:
        raise Exception(f'check failed: {text}')

    print(f"OK: {text}")


def s(value):
    # LWW returns an empty variable-length field as null
    return (value or "").strip()


def signIn(userid, passphrase):
    Globals.s.headers.pop('Authorization', None)
    Globals.myCreds = (userid, passphrase)
    MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")
    Globals.myCreds = None
    Globals.s.headers['Authorization'] = f"Bearer {Globals.myBearer}"
    Globals.myBearer = ""


def call(uri, okCodes=(200,)):
    resp = MyRequests.get(f"{Globals.pathPrefix}{uri}", None)
    if resp.status_code not in okCodes:
        raise Exception(f'GET {uri}: status code {resp.status_code} {resp.text}')

    try:
        body = json.loads(resp.text) if resp.text else {}
    except ValueError:
        body = {}
    print(f"GET {uri}: {resp.status_code} {s(body.get('retCode'))} {s(body.get('reasonCode'))} "
          f"{s(body.get('infoMessage'))}")
    return resp.status_code, body


def rows(uri):
    return call(uri)[1].get('deployments') or []


def ids(rs):
    return [r['deplID'] for r in rs]


def asMember(userid):
    step("1. GET /applications/{appID}: DEMO with the roles of the deployer")
    apps = call("/applications")[1]['applications']
    demo = next((a for a in apps if s(a['appCode']) == appCode), None)
    check(demo is not None, f"{appCode} is in GET /applications")
    code, app = call(f"/applications/{demo['appID']}")
    check(s(app['appCode']) == appCode and s(app['isMember']) == 'Y',
          f"{appCode}: {s(app['appName'])}, member Y, owner {s(app['isOwner'])}, "
          f"access group {s(app['accessGroup'])}")
    check(call("/applications/999999", (404,))[0] == 404, "an unknown application is 404")

    step("2. GET /deployments?appID=: every deployment of DEMO, newest first")
    appID = demo['appID']
    first = rows(f"/deployments?appID={appID}")
    check(len(first) > 0, f"{len(first)} deployments")
    check(ids(first) == sorted(ids(first), reverse=True), "newest first")
    if len(first) == 20:
        more = rows(f"/deployments?appID={appID}&deplID_since={first[-1]['deplID']}")
        check(all(d < first[-1]['deplID'] for d in ids(more)),
              f"next page: {len(more)} older deployments")

    step("3. Filters")
    d = first[0]
    byEnv = rows(f"/deployments?appID={appID}&envID_filter={d['envID']}")
    check(byEnv and all(r['envID'] == d['envID'] for r in byEnv), f"only {s(d['envCode'])}")
    byStatus = rows(f"/deployments?appID={appID}&deplStatus_filter={s(d['deplStatus'])}")
    check(all(s(r['deplStatus']) == s(d['deplStatus']) for r in byStatus),
          f"only status {s(d['deplStatus'])}")
    byVersion = rows(f"/deployments?appID={appID}&versionID_filter={d['versionID']}")
    check(all(r['versionID'] == d['versionID'] for r in byVersion), f"only {s(d['versionName'])}")
    check(call(f"/deployments?appID={appID}&deplStatus_filter=X", (400,))[1]['reasonCode'] == '03',
          "a status that isn't one is 08 03")

    step("4. appID 0: only the own requests")
    mine = rows(f"/deployments?appID=0&requestedBy_filter={userid}")
    check(mine and all(s(r['requestedBy']) == userid for r in mine),
          f"{len(mine)} own requests, in every application")
    check(call("/deployments?appID=0", (400,))[1]['reasonCode'] == '01',
          "without appID and without the own userid: 08 01")
    check(call("/deployments?appID=0&requestedBy_filter=SOMEONE", (400,))[1]['reasonCode'] == '01',
          "another user's requests without appID: 08 01")
    return appID


def asApproverOnly(appID, approver):
    step(f"5. {approver}, only an approver: the deployments it decided on")
    seen = rows(f"/deployments?appID={appID}")
    for d in seen:
        decisions = call(f"/approvals?deplID={d['deplID']}")[1].get('approvals') or []
        check(any(s(a['userID']) == approver for a in decisions),
              f"{approver} decided on deployment {d['deplID']}")
    print(f"  {len(seen)} deployments")
    code, app = call(f"/applications/{appID}")
    check(s(app['isApprover']) == 'Y' and s(app['isMember']) == 'N', "approver Y, member N")


def doStuff():
    userid = input("Deployer userid: ").strip().upper()
    passphrase = getpass(f"Passphrase of {userid}: ")
    signIn(userid, passphrase)
    appID = asMember(userid)

    approver = input("\nUserid that is only an approver of DEMO (Enter to skip): ").strip().upper()
    if approver:
        signIn(approver, getpass(f"Passphrase of {approver}: "))
        asApproverOnly(appID, approver)

    print("\nDone.")


doStuff()
