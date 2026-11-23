# Tests the administrators' paths of iteration 6a (docs/10-iteration-6.md)
# without the UI: applications (LWDM004 and LWDM204 with ADMINVIEW),
# environment controls and one environment (LWDM006 K and R), the allowlists
# and settings (LWDM201, LWDM001), the deployments of every application
# (LWDM211 with ADMINVIEW) and marking a run stuck (LWDM514).
#
#   python testIteration6a.py
#
# Needs an administrator (READ on the ADMINRES resource) and optionally the
# deployer of testIteration2.py, who must be refused. It leaves nothing
# behind: the test application and allowlist entry are deleted again, and
# DEMO's DEV controls and setting JOBMINS are written back unchanged. It
# never marks a real run stuck: only the refusals are tried.
import json
import requests

from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

appCode = "DEMO"
testCode = "T6ATEST"
testGroup = "T6ATEST"


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


def call(method, uri, data=None, okCodes=(200,)):
    resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)
    if resp.status_code not in okCodes:
        raise Exception(f'{method.upper()} {uri}: status code {resp.status_code} {resp.text}')

    try:
        body = json.loads(resp.text) if resp.text else {}
    except ValueError:
        body = {}
    print(f"{method.upper()} {uri}: {resp.status_code} {s(body.get('retCode'))} "
          f"{s(body.get('reasonCode'))} {s(body.get('infoMessage'))}")
    return body


def refused(method, uri, data, status, reason, text):
    body = call(method, uri, data, (status,))
    check(s(body.get('reasonCode')) == reason, f"{text}: {status}, 08 {reason}")
    return body


def applications():
    step("1. Applications (A1)")
    apps = call("get", "/admin/applications")['applications']
    demo = next((a for a in apps if s(a['appCode']) == appCode), None)
    check(demo is not None and s(demo['accessGroup']) != "",
          f"{appCode} in GET /admin/applications, access group {s(demo['accessGroup'])}")
    groups = {'accessGroup': s(demo['accessGroup']), 'ownerGroup': s(demo['ownerGroup'])}

    new = {'appCode': testCode.lower(), 'appName': 'Iteration 6a test',
           'appDescription': 'Made and deleted by testIteration6a.py', **groups}
    app = call("post", "/admin/applications", new, (201,))
    appID = app['appID']
    check(s(app['appCode']) == testCode, f"created {testCode}, appID {appID}, upper case")
    try:
        refused("post", "/admin/applications", new, 409, '11', "the same code again")
        refused("post", "/admin/applications", {**new, 'appCode': 'T6-X'}, 400, '02',
                "a code with a hyphen")
        refused("post", "/admin/applications", {**new, 'appCode': 'T6B',
                'ownerGroup': 'NOSUCHGR'}, 400, '02', "a group not in the allowlist")

        got = call("get", f"/admin/applications/{appID}")
        check(s(got['appDescription']).startswith('Made'), "GET /admin/applications/{appID}")
        upd = call("put", f"/admin/applications/{appID}", {**new, 'appCode': testCode,
                   'appName': 'Iteration 6a test, changed'})
        check(s(upd['appName']).endswith('changed'), "PUT changes the name")
        user = call("get", f"/applications/{appID}")
        check(s(user['appName']).endswith('changed'),
              "an administrator also sees it through GET /applications/{appID}")
    finally:
        call("delete", f"/admin/applications/{appID}")
    call("get", f"/admin/applications/{appID}", okCodes=(404,))
    print("OK: deleted, and not found any more")
    refused("delete", f"/admin/applications/{demo['appID']}", None, 409, '53',
            f"{appCode} has deployments")
    return demo, groups


def controls(demo):
    step("2. Environment controls (A2) and GET /environments/{envID}")
    envs = call("get", f"/environments?appID={demo['appID']}")['environments']
    dev = envs[0]
    env = call("get", f"/environments/{dev['envID']}")
    check(s(env['envCode']) == s(dev['envCode']) and 'execNode' in env,
          f"{s(env['envCode'])}: deploy userid {s(env['deployUser'])}, "
          f"execution node '{s(env['execNode'])}'")
    same = {'deployUser': s(env['deployUser']), 'approvalReq': s(env['approvalReq']),
            'approverGroup': s(env['approverGroup']),
            'approvalCount': env['approvalCount'],
            'deployerGroup': s(env['deployerGroup']), 'execNode': s(env['execNode'])}
    uri = f"/admin/environmentControls/{dev['envID']}"
    back = call("put", uri, same)
    check(all(s(str(back[k])) == s(str(v)) for k, v in same.items()),
          "written back unchanged")
    refused("put", uri, {**same, 'approvalReq': 'Y', 'approverGroup': ''}, 400, '02',
            "approval without an approver group")
    refused("put", uri, {**same, 'deployUser': 'NOSUCHUS'}, 400, '02',
            "a deploy userid not in the allowlist")
    refused("put", uri, {**same, 'execNode': '9BAD'}, 400, '02', "a node name with a digit first")
    call("get", "/environments/999999999", okCodes=(404,))
    print("OK: an unknown environment is 404")


def allowlists(groups):
    step("3. Allowlists (A3)")
    rows = call("get", "/admin/refTables?tableID=RACFGRP")['refTables']
    check(any(s(r['tabKey']) == groups['accessGroup'] for r in rows),
          f"{groups['accessGroup']} is in RACFGRP")
    entry = {'tableID': 'RACFGRP', 'tabKey': testGroup, 'tabValue': 'testIteration6a.py'}
    call("post", "/admin/refTables", entry, (201,))
    try:
        refused("post", "/admin/refTables", entry, 409, '11', "the same group again")
        refused("post", "/admin/refTables", {**entry, 'tabKey': '1GROUP'}, 400, '02',
                "a key that isn't a RACF name")
        upd = call("put", f"/admin/refTables/RACFGRP?tabKey={testGroup}",
                   {'tabValue': 'testIteration6a.py, changed'})
        check(s(upd['tabValue']).endswith('changed'), "PUT changes the description")
    finally:
        call("delete", f"/admin/refTables/RACFGRP?tabKey={testGroup}")
    body = refused("delete", f"/admin/refTables/RACFGRP?tabKey={groups['accessGroup']}",
                   None, 409, '53', "a group still in use")
    check('still used' in s(body['infoMessage']), "the message says where")
    refused("post", "/admin/refTables", {'tableID': 'SETTINGS', 'tabKey': 'NEWKEY',
            'tabValue': '1'}, 403, '50', "no new settings")


def settings():
    step("4. Settings (A5)")
    rows = call("get", "/admin/refTables?tableID=SETTINGS")['refTables']
    jobmins = next(r for r in rows if s(r['tabKey']) == 'JOBMINS')
    value = s(jobmins['tabValue'])
    back = call("put", "/admin/refTables/SETTINGS?tabKey=JOBMINS", {'tabValue': value})
    check(s(back['tabValue']) == value, f"JOBMINS written back unchanged: {value}")
    refused("put", "/admin/refTables/SETTINGS?tabKey=JOBMINS", {'tabValue': '4'}, 400, '02',
            "JOBMINS below 5")
    refused("put", "/admin/refTables/SETTINGS?tabKey=ADMINRES", {'tabValue': 'X'}, 403, '50',
            "ADMINRES comes from envs/<env>.yaml")
    refused("delete", "/admin/refTables/SETTINGS?tabKey=JOBMINS", None, 403, '50',
            "settings are never deleted")


def deployments(demo):
    step("5. Deployments of every application (A4) and mark stuck")
    all_ = call("get", "/admin/deployments")['deployments'] or []
    check(len(all_) > 0, f"{len(all_)} deployments, newest first, of "
          f"{len({d['appID'] for d in all_})} applications")
    mine = call("get", f"/admin/deployments?appID_filter={demo['appID']}")['deployments'] or []
    check(all(d['appID'] == demo['appID'] for d in mine), f"only {appCode} with appID_filter")
    refused("get", "/admin/deployments?deplStatus_filter=X", None, 400, '03',
            "a status that isn't one")

    refused("post", "/admin/stuckRuns/999999999", None, 404, '31', "an unknown run")
    ended = next((d for d in all_ if s(d['deplStatus']) == 'S'), None)
    if ended:
        runs = call("get", f"/jobRuns?deplID={ended['deplID']}&jobNo=1")['runs'] or []
        if runs:
            refused("post", f"/admin/stuckRuns/{runs[0]['runID']}", None, 409, '53',
                    f"run {runs[0]['runID']} has ended")


def notAdmin(method, uri, text):
    # RACF lets only administrators use transaction LWDA, so LWW refuses
    # with 403 before the module runs, without LWD's envelope. The module's
    # own 08 50 is for a userid with LWDA but no READ on ADMINRES.
    body = call(method, uri, None, (403,))
    reason = s(body.get('reasonCode'))
    check(reason in ('', '50'), f"{text}: 403, " +
          ("refused by RACF on LWDA" if reason == '' else "08 50 from the module"))


def asOther(userid):
    step(f"6. {userid}, not an administrator")
    notAdmin("get", "/admin/applications", "GET /admin/applications")
    notAdmin("get", "/admin/refTables?tableID=RACFGRP", "GET /admin/refTables")
    notAdmin("get", "/admin/deployments", "GET /admin/deployments")
    notAdmin("post", "/admin/stuckRuns/1", "POST /admin/stuckRuns")


def doStuff():
    admin = input("Administrator userid: ").strip().upper()
    signIn(admin, getpass(f"Passphrase of {admin}: "))
    demo, groups = applications()
    controls(demo)
    allowlists(groups)
    settings()
    deployments(demo)

    other = input("\nUserid that is not an administrator (Enter to skip): ").strip().upper()
    if other:
        signIn(other, getpass(f"Passphrase of {other}: "))
        asOther(other)

    print("\nDone.")


doStuff()
