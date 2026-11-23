# Walks through "Mocks and tests" of docs/11-iteration-7.md: the profile
# (PUT /me) and the notification mails (S5).
#  1. PUT /me: each setting off and on again; a value other than Y or N is
#     refused.
#  2. With notifyOwn Y, the deployer deploys V1.0.0 of DEMO to DEV and waits
#     for it to end: the result step's "succeeded" queues a mail for the
#     requester, which the next tick sends.
#  3. With notifyOwn N, the same deployment again: no mail.
# The script can't see the mail queue or the inbox: it says when to look.
#
#   python testIteration7.py
#
# Needs the deployer of testIteration2.py with an email address in RACF
# (WAEMAIL), copied by JCL/LWDMAIL. That job only reads the userids LWD
# knows, those that signed in at least once: sign in first (a run of this
# script does), then run the job, then this script. And a scheduled
# LWDTICK: it sends the queued mails ('mails sent' in its STDOUT). Every run
# submits real jobs under the deploy userid. The settings are left as
# they were.
import json
import requests
import time

from getpass import getpass
from Globals import Globals
from MyRequests import MyRequests
from testTarget import useTarget

useTarget()

appCode = "DEMO"
envCode = "DEV"
versionName = "V1.0.0"
pollSeconds = 5
pollMax = 60
FIELDS = ('notifyApprove', 'notifyOwn', 'notifyApp')


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
    try:
        body = json.loads(resp.text) if resp.text else {}
    except ValueError:
        body = {}
    print(f"{method.upper()} {uri}: {resp.status_code} {s(body.get('retCode'))} "
          f"{s(body.get('reasonCode'))} {s(body.get('infoMessage'))}")
    if resp.status_code not in okCodes:
        raise Exception(f'{method.upper()} {uri}: status code {resp.status_code} {resp.text}')
    return body


def settings(me):
    return {f: s(me[f]) for f in FIELDS}


def profile():
    step("1. PUT /me")
    me = call("get", "/me")
    before = settings(me)
    print(f"  address: {s(me['email']) or '(none: run JCL/LWDMAIL first)'}; {before}")
    for f in FIELDS:
        flipped = {**before, f: 'N' if before[f] == 'Y' else 'Y'}
        got = settings(call("put", "/me", flipped))
        check(got == flipped, f"{f} switched to {flipped[f]}")
    body = call("put", "/me", {**before, 'notifyOwn': 'X'}, (400,))
    check(s(body['reasonCode']) == '02', "a value other than Y or N: 08 02")
    check(settings(call("put", "/me", before)) == before, "back as they were")
    return me, before


def find(items, key, value, hint):
    # The item whose key is value; a clear message when it isn't there
    found = next((i for i in items or [] if s(i[key]) == value), None)
    check(found is not None, f"{key} {value} is listed" if found is not None
          else f"{key} {value} not found: is it there, and is the userid in {hint}?")
    return found


def deploy(note):
    app = find(call("get", "/applications")['applications'], 'appCode', appCode,
               "the access group of the application")
    env = find(call("get", f"/environments?appID={app['appID']}")['environments'],
               'envCode', envCode, "the application")
    check(not env['activeDeplID'], f"{envCode} is free" if not env['activeDeplID']
          else f"{envCode} is held by {env['activeDeplID']}: cancel it first")
    ver = find(call("get", f"/versions?appID={app['appID']}")['versions'],
               'versionName', versionName, "the application (run testIteration2.py)")
    d = call("post", "/deployments", {'appID': app['appID'], 'envID': env['envID'],
             'versionID': ver['versionID'], 'requestNote': note}, (201,))
    st = s(d['deplStatus'])
    for i in range(0, pollMax):
        if st not in ('Q', 'U'):
            break
        time.sleep(pollSeconds)
        st = s(call("get", f"/deployments/{d['deplID']}")['deplStatus'])
    check(st == 'S', f"deployment {d['deplID']} succeeded (S), it is {st}")
    return d['deplID']


def doStuff():
    userid = input("Deployer userid: ").strip().upper()
    signIn(userid, getpass(f"Passphrase of {userid}: "))
    me, before = profile()
    if not s(me['email']):
        print("\nNo address for this userid. It is signed in now, so LWD knows it: "
              "set WAEMAIL in RACF if needed, run JCL/LWDMAIL, then run this script again.")
        return

    step("2. A deployment with notifyOwn Y: one mail")
    call("put", "/me", {**before, 'notifyOwn': 'Y'})
    d1 = deploy('testIteration7: with a mail')
    print(f"  After the next LWDTICK ('mails sent' 1 or more in its STDOUT), "
          f"{s(me['email'])} has 'LWD: {appCode} {versionName} to {envCode} "
          f"succeeded' about deployment {d1}.")

    step("3. A deployment with notifyOwn N: no mail")
    call("put", "/me", {**before, 'notifyOwn': 'N'})
    try:
        d2 = deploy('testIteration7: without a mail')
        print(f"  No mail about deployment {d2}.")
    finally:
        call("put", "/me", before)
        print("  Settings back as they were.")

    print("\nDone.")


doStuff()
