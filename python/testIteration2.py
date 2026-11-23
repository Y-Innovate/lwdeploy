# Walks through "Trying it" in docs/06-iteration-2.md: approval with two
# approvers, a rejection, retry and continue after a failure, a queue that the
# scheduler or a cancel moves on, and a deployment scheduled for later.
#
#   python testIteration2.py [tick.json]
#
# Needs three userids, all in USERGROUP: a deployer (in the demo access and
# owner groups) and two approvers (in the demo approver group, not the
# deployer). With tick.json (see tick.py) the test calls POST /schedulerTicks
# itself, as the scheduler's Entra application; without it, it waits for the
# scheduled LWDTICK job. Every run submits real jobs under the deploy userid.
import json
import requests
import sys
import time

from datetime import datetime, timedelta
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
# Without tick.json: how long to wait for the scheduled tick
tickWaitMinutes = 15

tickConfig = None
passphrases = {}
tokens = {}
current = None


def step(text):
    print(f"\n=== {text}")


def check(condition, text):
    if not condition:
        raise Exception(f'check failed: {text}')

    print(f"OK: {text}")


def s(value):
    # LWW returns an empty variable-length field as null
    return (value or "").strip()


def signIn(userid):
    # The token goes on the session only. With Globals.myBearer set, MyRequests
    # would itself get a new token and send the request again after every 4xx
    # but 404, and this test expects several. call() is the only retry.
    Globals.s.headers.pop('Authorization', None)
    Globals.myCreds = (userid, passphrases[userid])
    MyRequests.getBearerToken(f"{Globals.pathPrefix}/token")
    Globals.myCreds = None
    tokens[userid] = Globals.myBearer
    Globals.myBearer = ""


def asUser(userid):
    global current
    current = userid
    Globals.s.headers['Authorization'] = f"Bearer {tokens[userid]}"


def call(method, uri, data=None, okCodes=(200,)):
    for attempt in range(0, 2):
        resp = getattr(MyRequests, method)(f"{Globals.pathPrefix}{uri}", data)
        print(f"[{current}] {method.upper()} {uri}: {resp.status_code} {resp.text[:300]}")

        if (resp.status_code != 401 or current == "TICK" or attempt > 0):
            break

        print("Signing in again")
        signIn(current)
        asUser(current)

    if (resp.status_code not in okCodes):
        raise Exception(f'status code {str(resp.status_code)} {resp.text}')

    return json.loads(resp.text) if resp.text else {}


def refused(method, uri, data, status, reason):
    answer = call(method, uri, data, (status,))
    check(s(answer.get('reasonCode')) == reason,
          f"{method.upper()} {uri} refused with {status} and reason {reason}")


def find(rows, field, value):
    for row in rows:
        if (s(row[field]) == value):
            return row

    raise Exception(f'{field} {value} not found')


def deploy(app, env, version, note, expect, startAfter=None):
    data = {'appID': app, 'envID': env, 'versionID': version, 'requestNote': note}
    if startAfter:
        data['startAfter'] = startAfter
    d = call("post", "/deployments", data, (201,))
    check(s(d['deplStatus']) == expect,
          f"deployment {d['deplID']} is {expect}, it is {s(d['deplStatus'])}")
    return d


def status(deplID):
    return s(call("get", f"/deployments/{deplID}")['deplStatus'])


def waitWhile(deplID, statuses, seconds=pollSeconds, tries=pollMax):
    st = ''
    for i in range(0, tries):
        st = status(deplID)

        if (st not in statuses):
            break

        time.sleep(seconds)

    return st


def tick():
    # One tick, as the scheduler: through tick.json, or by waiting for LWDTICK
    if tickConfig is None:
        print(f"Waiting for the scheduled tick (up to {tickWaitMinutes} minutes)")
        return None

    saved = current
    with open(tickConfig["credsFile"], "r") as credsFile:
        Globals.myCreds = json.load(credsFile)
    Globals.s.headers.pop('Authorization', None)
    MyRequests.getBearerToken(tickConfig["tokenUrl"])
    Globals.myCreds = None
    tokens["TICK"] = Globals.myBearer
    Globals.myBearer = ""
    asUser("TICK")
    answer = call("post", "/schedulerTicks", {})
    asUser(saved)
    return answer


def waitForScheduler(deplID):
    # A Q deployment that only the scheduler starts: tick, or wait for LWDTICK
    if tickConfig is None:
        return waitWhile(deplID, ('Q',), 30, tickWaitMinutes * 2)

    answer = tick()
    check(answer['startedDeplID'] == deplID, f"the tick started deployment {deplID}")
    return status(deplID)


def checkFree(envs):
    held = [f"{s(e['envCode'])} by deployment {e['activeDeplID']}"
            for e in envs if e['activeDeplID']]
    check(not held, "DEV, TST and PRD are free" if not held
          else f"held: {', '.join(held)}; cancel first, POST /cancellations/{{deplID}}")


def events(deplID):
    return [s(e['eventType']) for e in call("get", f"/deploymentEvents?deplID={deplID}")['events']]


def doStuff():
    global tickConfig

    if len(sys.argv) > 1:
        with open(sys.argv[1], "r") as configFile:
            tickConfig = json.load(configFile)

    deployer = input("Deployer userid: ").strip().upper()
    approver1 = input("First approver userid: ").strip().upper()
    approver2 = input("Second approver userid: ").strip().upper()
    check(len({deployer, approver1, approver2}) == 3,
          "deployer and the two approvers are three different userids")
    for u in (deployer, approver1, approver2):
        passphrases[u] = getpass(f"Passphrase of {u}: ")

    step("1. Sign in as all three; the demo application and its environments")
    for u in (deployer, approver1, approver2):
        signIn(u)
    asUser(deployer)
    app = find(call("get", "/applications")['applications'], 'appCode', appCode)['appID']
    envs = call("get", f"/environments?appID={app}")['environments']
    dev = find(envs, 'envCode', 'DEV')['envID']
    tst = find(envs, 'envCode', 'TST')['envID']
    prd = find(envs, 'envCode', 'PRD')
    check(prd['approvalCount'] == 2, "PRD needs two approvals (SEEDITR2.sql)")
    prd = prd['envID']
    checkFree(envs)
    versions = call("get", f"/versions?appID={app}")['versions']
    good = find(versions, 'versionName', goodVersion)['versionID']
    bad = find(versions, 'versionName', badVersion)['versionID']

    step(f"2. {goodVersion} through DEV and TST, for the promotion gate of PRD")
    for env in (dev, tst):
        d = deploy(app, env, good, 'testIteration2: gate', 'U')
        check(waitWhile(d['deplID'], ('U',)) == 'S', f"deployment {d['deplID']} succeeded")

    step("3. PRD: two approvals, then it starts at once")
    d = deploy(app, prd, good, 'testIteration2: to PRD', 'W')['deplID']
    asUser(approver1)
    waiting = call("get", "/approvalRequests")['approvalRequests']
    check(any(r['deplID'] == d for r in waiting), f"{approver1} sees {d} waiting")
    check(s(call("get", f"/deployments/{d}")['canApprove']) == 'Y', "canApprove is Y")
    asUser(deployer)
    refused("post", "/approvals", {'deplID': d, 'decision': 'A'}, 403, '55')
    asUser(approver1)
    a = call("post", "/approvals", {'deplID': d, 'decision': 'A',
                                    'commentText': 'First look: fine'}, (201,))
    check(s(a['deplStatus']) == 'W' and a['approvedCount'] == 1, "1 of 2: still W")
    refused("post", "/approvals", {'deplID': d, 'decision': 'A'}, 403, '55')
    waiting = call("get", "/approvalRequests")['approvalRequests']
    check(not any(r['deplID'] == d for r in waiting), f"{approver1} no longer sees it")
    asUser(approver2)
    a = call("post", "/approvals", {'deplID': d, 'decision': 'A'}, (201,))
    check(s(a['deplStatus']) == 'U' and a['approvedCount'] == 2,
          "2 of 2: started at once (U)")
    check(waitWhile(d, ('U',)) == 'S', f"deployment {d} succeeded")
    decisions = call("get", f"/approvals?deplID={d}")['approvals']
    check(len(decisions) == 2, "two decisions recorded")
    check(events(d) == ['R', 'A', 'A', 'Q', 'U', 'S'], "events R A A Q U S")

    step("4. PRD again: one rejection is enough, with a reason")
    asUser(deployer)
    d = deploy(app, prd, good, 'testIteration2: to be rejected', 'W')['deplID']
    asUser(approver1)
    refused("post", "/approvals", {'deplID': d, 'decision': 'R'}, 400, '05')
    a = call("post", "/approvals", {'deplID': d, 'decision': 'R',
                                    'commentText': 'Not this week'}, (201,))
    check(s(a['deplStatus']) == 'J', "rejected (J)")

    step(f"5. {badVersion} to DEV fails in job 2; retry fails again")
    asUser(deployer)
    d = deploy(app, dev, bad, 'testIteration2: retry and continue', 'U')['deplID']
    check(waitWhile(d, ('U',)) == 'F', f"deployment {d} failed")
    check(s(call("get", f"/deployments/{d}")['canRetry']) == 'Y', "canRetry is Y")
    r = call("post", f"/retries/{d}", {'commentText': 'Once more'})
    check(s(r['deplStatus']) == 'U', "retried: U")
    check(waitWhile(d, ('U',)) == 'F', "failed again: DEMORC is still 8")
    runs = call("get", f"/jobRuns?deplID={d}&jobNo=2")['runs']
    check(len(runs) == 2 and all(s(r['jobResult']) == 'H' for r in runs),
          "job 2 has two runs, both above the highest RC")

    step("6. Continue: skip job 2 with a reason; it was the last job, so S")
    refused("post", f"/continuations/{d}", {}, 400, '05')
    c = call("post", f"/continuations/{d}", {'commentText': 'Fixed by hand'})
    check(s(c['deplStatus']) == 'S', "continued: no job left, succeeded")
    jobs = call("get", f"/deploymentJobs?deplID={d}")['jobs']
    check(s(jobs[1]['jobStatus']) == 'K' and s(jobs[1]['skipReason']) == 'Fixed by hand',
          "job 2 is skipped with its reason")
    check(events(d) == ['R', 'U', 'F', 'T', 'F', 'K', 'S'],
          "events R U F T F K S: the retry (T) and the skip (K) are in the history")

    step("7. A queue: the second deployment to DEV waits for the scheduler")
    first = deploy(app, dev, good, 'testIteration2: first', 'U')['deplID']
    second = deploy(app, dev, good, 'testIteration2: second', 'Q')['deplID']
    check(waitWhile(first, ('U',)) == 'S', f"{first} succeeded")
    check(status(second) == 'Q', f"{second} still waits: only the scheduler starts it")
    st = waitForScheduler(second)
    check(st in ('U', 'S'), f"the scheduler started {second}")
    check(waitWhile(second, ('U',)) == 'S', f"{second} succeeded")

    step("8. A cancel frees the environment and starts the next in the queue")
    f = deploy(app, dev, bad, 'testIteration2: holds DEV', 'U')['deplID']
    check(waitWhile(f, ('U',)) == 'F', f"{f} failed and holds DEV")
    q = deploy(app, dev, good, 'testIteration2: waits behind it', 'Q')['deplID']
    c = call("post", f"/cancellations/{f}", {'commentText': 'Make way'})
    check(s(c['deplStatus']) == 'C', f"{f} cancelled")
    check(status(q) in ('U', 'S'), f"{q} started by the cancel")
    check(waitWhile(q, ('U',)) == 'S', f"{q} succeeded")

    step("9. Scheduled for later: TST in one minute")
    later = (datetime.now() + timedelta(minutes=1)).strftime("%Y-%m-%d-%H.%M.%S.000000")
    d = deploy(app, tst, good, 'testIteration2: later', 'Q', later)['deplID']
    print("Waiting 70 seconds for its time")
    time.sleep(70)
    st = waitForScheduler(d)
    check(st in ('U', 'S'), f"the scheduler started {d} after its time")
    check(waitWhile(d, ('U',)) == 'S', f"{d} succeeded")

    print(f"\nDone. DEV, TST and PRD run {goodVersion}.")


doStuff()
