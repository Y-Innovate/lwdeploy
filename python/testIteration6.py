# Tests both halves of iteration 6 (docs/10-iteration-6.md) without the UI:
# an administrator puts a new application under LWD, its owner sets it up,
# and a deployment of it succeeds.
#  1. The administrator creates application T6TEST with DEMO's groups.
#  2. The owner adds DEV, TST and PRD; a new one can't be deployed to.
#  3. The administrator sets DEV's controls: DEMO DEV's deploy userid, no
#     approval.
#  4. The owner adds two templates with JCL (and a refused save with a JOB
#     statement), application and environment variables, and a version.
#  5. The deployer deploys the version to DEV; it must succeed.
#  6. Deleting the application is refused while it has a deployment. The
#     script leaves T6TEST in place and says how to remove it.
#
#   python testIteration6.py
#
# Needs three userids, which may be the same person's: an administrator, an
# owner of DEMO (in its owner group) and a deployer (in its access group), as
# T6TEST gets DEMO's groups. And a scheduled LWDTICK and the PassTicket setup
# (iteration 4): the deployment submits two IEFBR14 jobs under the deploy
# userid. Run it again after removing T6TEST.
import base64
import json
import requests
import time

from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

demoCode = "DEMO"
testCode = "T6TEST"
pollSeconds = 5
pollMax = 60

JOB1 = """//* Iteration 6 test: ${LWDAPP} ${LWDVER} to ${LWDENV}
//STEP1    EXEC PGM=IEFBR14
//* From ${LWDLOC} to ${TARGET}"""
JOB2 = """//STEP1    EXEC PGM=IEFBR14
//* Environment note: ${ENVNOTE}"""


def step(text):
    print(f"\n=== {text}")


def check(condition, text):
    if not condition:
        raise Exception(f'check failed: {text}')

    print(f"OK: {text}")


def s(value):
    # LWW returns an empty variable-length field as null
    return (value or "").strip()


users = {}


def signIn(role):
    userid, passphrase = users[role]
    Globals.s.headers.pop('Authorization', None)
    Globals.myCreds = (userid, passphrase)
    MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")
    Globals.myCreds = None
    Globals.s.headers['Authorization'] = f"Bearer {Globals.myBearer}"
    Globals.myBearer = ""
    print(f"(signed in as {userid}, {role})")


def show(method, uri, resp):
    try:
        body = json.loads(resp.text) if resp.text else {}
    except ValueError:
        body = {}
    print(f"{method.upper()} {uri}: {resp.status_code} {s(body.get('retCode'))} "
          f"{s(body.get('reasonCode'))} {s(body.get('infoMessage'))}")
    return body


def call(method, uri, data=None, okCodes=(200,)):
    resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)
    body = show(method, uri, resp)
    if resp.status_code not in okCodes:
        raise Exception(f'{method.upper()} {uri}: status code {resp.status_code} {resp.text}')
    return body


def saveJcl(templateID, text, note, okCodes=(201,)):
    # multipart/form-data, as the UI sends it: jcl is base64 of UTF-8
    files = {'jcl': (None, base64.b64encode(text.encode('utf-8')).decode('ascii')),
             'changeNote': (None, note)}
    uri = f"/templateJcl/{templateID}"
    resp = MyRequests.post(f"{Globals.pathPrefix}{uri}", None, files)
    body = show("post", uri, resp)
    if resp.status_code not in okCodes:
        raise Exception(f'POST {uri}: status code {resp.status_code} {resp.text}')
    return body


def admin1():
    step("1. The administrator creates the application")
    apps = call("get", "/admin/applications")['applications']
    check(not any(s(a['appCode']) == testCode for a in apps),
          f"no {testCode} yet (remove it first, see the end of this script)")
    demo = next(a for a in apps if s(a['appCode']) == demoCode)
    app = call("post", "/admin/applications", {
        'appCode': testCode, 'appName': 'Iteration 6 test',
        'appDescription': 'Made by testIteration6.py',
        'accessGroup': s(demo['accessGroup']), 'ownerGroup': s(demo['ownerGroup'])}, (201,))
    check(app['appID'] > 0, f"{testCode} is application {app['appID']}")
    demoEnvs = call("get", f"/environments?appID={demo['appID']}")['environments']
    demoDev = call("get", f"/environments/{demoEnvs[0]['envID']}")
    return app['appID'], s(demoDev['deployUser'])


def owner2(appID):
    step("2. The owner adds three environments")
    envs = {}
    for code, name, gate in (('DEV', 'Development', 'N'), ('TST', 'Test', 'Y'),
                             ('PRD', 'Production', 'Y')):
        e = call("post", "/environments", {'appID': appID, 'envCode': code.lower(),
                 'envName': name, 'promoGate': gate}, (201,))
        envs[code] = e
    check([envs[c]['sortOrder'] for c in ('DEV', 'TST', 'PRD')] == [1, 2, 3],
          "in order 1, 2, 3")
    dev = envs['DEV']
    check(s(dev['approvalReq']) == 'Y' and dev['approvalCount'] == 1
          and s(dev['deployUser']) == '' and s(dev['canDeploy']) == 'N',
          "protected defaults: approval with 1, no deploy userid, can't deploy")
    body = call("post", "/environments", {'appID': appID, 'envCode': 'DEV',
                'envName': 'Again'}, (409,))
    check(s(body['reasonCode']) == '11', "DEV twice: 08 11")
    upd = call("put", f"/environments/{envs['PRD']['envID']}",
               {'envCode': 'PRD', 'envName': 'Production', 'envDescription': 'Live',
                'sortOrder': 0, 'promoGate': 'Y'})
    check(upd['sortOrder'] == 3 and s(upd['envDescription']) == 'Live',
          "PUT with sortOrder 0 keeps the order")
    return envs


def admin3(envs, deployUser):
    step("3. The administrator sets DEV's controls")
    e = call("put", f"/admin/environmentControls/{envs['DEV']['envID']}",
             {'deployUser': deployUser, 'approvalReq': 'N', 'approverGroup': '',
              'approvalCount': 0, 'deployerGroup': '', 'execNode': ''})
    check(s(e['deployUser']) == deployUser and s(e['approvalReq']) == 'N',
          f"DEV: deploy userid {deployUser}, no approval")


def owner4(appID, envs):
    step("4. The owner adds templates, variables and a version")
    t1 = call("post", "/templates", {'appID': appID, 'templateName': 'First job',
              'maxRC': 0}, (201,))
    t2 = call("post", "/templates", {'appID': appID, 'templateName': 'Second job',
              'maxRC': 4}, (201,))
    check(t1['currentRev'] == 0 and t2['sortOrder'] == t1['sortOrder'] + 1,
          "two templates without JCL, in order")

    body = saveJcl(t1['templateID'], "//T6TEST JOB (1),CLASS=A\n" + JOB1, 'With a JOB card',
                   (400,))
    check(s(body['reasonCode']) == '56' and 'Line 1' in s(body['infoMessage']),
          "a JOB statement: 08 56, line 1")
    r1 = saveJcl(t1['templateID'], JOB1 + "\n", 'First version')
    check(r1['revision'] == 1 and r1['lineCount'] == 3 and r1['warningCount'] == 1,
          f"revision 1, 3 lines, 1 warning: {s(r1['infoMessage'])}")
    saveJcl(t2['templateID'], JOB2, 'First version')
    jcl = call("get", f"/templateJcl/{t1['templateID']}")
    text = base64.b64decode(jcl['jcl']).decode('utf-8')
    check(text == JOB1, "GET /templateJcl gives the JCL back, without the last LF")
    revs = call("get", f"/templateRevisions?templateID={t1['templateID']}")['revisions']
    check([r['revision'] for r in revs] == [1], "one revision")

    call("post", "/variables", {'appID': appID, 'varName': 'target',
         'varValue': 'T6TEST.LOAD', 'varDescription': 'Where the modules go'}, (201,))
    call("post", "/variables", {'appID': appID, 'envID': envs['DEV']['envID'],
         'varName': 'ENVNOTE', 'varValue': 'only in DEV'}, (201,))
    body = call("post", "/variables", {'appID': appID, 'varName': 'LWDAPP',
                'varValue': 'x'}, (400,))
    check(s(body['reasonCode']) == '02', "a name starting with LWD: 08 02")
    vars_ = call("get", f"/variables?appID={appID}")['variables']
    check([s(v['varName']) for v in vars_] == ['TARGET'], "TARGET at application level")

    v = call("post", "/versions", {'appID': appID, 'versionName': 'V6.0.0',
             'locType': 'D', 'location': 'T6TEST.V600'}, (201,))
    upd = call("put", f"/versions/{v['versionID']}", {'versionName': 'V6.0.0',
               'locType': 'D', 'location': 'T6TEST.V600',
               'versionDescription': 'Iteration 6'})
    check(s(upd['versionDescription']) == 'Iteration 6', "a version never deployed can change")
    return v['versionID']


def deploy5(appID, envs, versionID):
    step("5. The deployer deploys V6.0.0 to DEV")
    d = call("post", "/deployments", {'appID': appID, 'envID': envs['DEV']['envID'],
             'versionID': versionID, 'requestNote': 'testIteration6'}, (201,))
    st = s(d['deplStatus'])
    for i in range(0, pollMax):
        if st not in ('Q', 'U'):
            break
        time.sleep(pollSeconds)
        st = s(call("get", f"/deployments/{d['deplID']}")['deplStatus'])
    check(st == 'S', f"deployment {d['deplID']} succeeded (S), it is {st}")
    jcl = call("get", f"/deploymentJcl/{d['deplID']}?jobNo=1")
    text = base64.b64decode(jcl['jcl']).decode('utf-8')
    check('T6TEST V6.0.0 to DEV' in text and 'T6TEST.LOAD' in text,
          "the frozen JCL has the variables filled in")
    return d['deplID']


def end6(appID, versionID, deplID):
    step("6. Deleting is refused now")
    signIn('owner')
    body = call("delete", f"/versions/{versionID}", okCodes=(409,))
    check(s(body['reasonCode']) == '53', "a deployed version can't be deleted: 08 53")
    signIn('admin')
    body = call("delete", f"/admin/applications/{appID}", okCodes=(409,))
    check(s(body['reasonCode']) == '53', "an application with a deployment: 08 53")
    print(f"\n{testCode} (appID {appID}) stays, with deployment {deplID}. To run this "
          "script again, remove it in DB2: the rows of deployment "
          f"{deplID} first (DEPLEVENTS, JOBSTEPS, SPOOLLINES, SPOOLFILES, JOBRUNS, "
          "JCLLINES, DEPLJOBS, DEPLOYMENTS), then DELETE /admin/applications/"
          f"{appID}.")


def doStuff():
    for role in ('admin', 'owner', 'deployer'):
        userid = input(f"{role.capitalize()} userid: ").strip().upper()
        same = next((users[r] for r in users if users[r][0] == userid), None)
        users[role] = same or (userid, getpass(f"Passphrase of {userid}: "))

    signIn('admin')
    appID, deployUser = admin1()
    signIn('owner')
    envs = owner2(appID)
    signIn('admin')
    admin3(envs, deployUser)
    signIn('owner')
    versionID = owner4(appID, envs)
    signIn('deployer')
    deplID = deploy5(appID, envs, versionID)
    end6(appID, versionID, deplID)

    print("\nDone.")


doStuff()
