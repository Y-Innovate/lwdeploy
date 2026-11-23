# One tick of the LWD scheduler (S4), for JCL/LWDTICK through tick.sh, or by hand:
#   python tick.py /path/to/tick.json
# Signs in to Entra with client credentials, then calls POST /schedulerTicks
# until the answer says no more deployments are due (moreDue N), at most maxCalls
# times. Each call expires old approval requests, fails stuck runs and starts one
# due deployment (LWDM930). Exit status 0 when every call succeeded, 8 otherwise,
# so a workload scheduler sees a failed tick.
#
# tick.json, readable by the scheduler's userid only, as it points to the secret:
# {
#   "host": "https://<host>:<port>",
#   "tokenUrl": "https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token",
#   "credsFile": "/u/lwdschd/.creds",
#   "caBundle": "/u/lwdschd/ca.pem",
#   "pathPrefix": "/lwdeploy/API/v1",
#   "maxCalls": 20
# }
# credsFile is JSON with client_id, client_secret, scope and grant_type
# (client_credentials), as uploadLWW.py uses it. caBundle is optional: the CA
# certificates that LWW's certificate and Entra's chain up to; without it the
# certifi bundle of requests is used. LWW maps the Entra application to the
# scheduler's userid (setting SCHEDUSR). A signed JWT (client assertion) can
# replace the client secret later: only getToken() changes.
import json
import sys
import requests

from datetime import datetime
from Globals import Globals
from MyRequests import MyRequests


def log(text):
    print(f"{datetime.now():%Y-%m-%d %H:%M:%S} {text}", flush=True)


def getToken(config):
    with open(config["credsFile"], "r") as credsFile:
        Globals.myCreds = json.load(credsFile)

    MyRequests.getBearerToken(config["tokenUrl"])


def tick(prefix):
    resp = MyRequests.post(f"{prefix}/schedulerTicks", {})

    if resp.status_code != 200:
        raise Exception(f"POST /schedulerTicks: {resp.status_code} {resp.text[:400]}")

    answer = json.loads(resp.text)
    log(f"expired {answer['expiredCount']}, stuck {answer['stuckCount']}, "
        f"started {answer['startedDeplID']}, more due {answer['moreDue']}, "
        f"mails sent {answer.get('mailsSent', 0)}")
    return answer


def main():
    if len(sys.argv) < 2:
        print("Usage: python tick.py /path/to/tick.json")
        return 8

    with open(sys.argv[1], "r") as configFile:
        config = json.load(configFile)

    Globals.myHost = config["host"].rstrip("/")
    Globals.myDebug = config.get("debug", 0)
    Globals.s = requests.sessions.Session()

    if config.get("caBundle"):
        Globals.s.verify = config["caBundle"]

    prefix = config.get("pathPrefix", "/lwdeploy/API/v1")
    maxCalls = config.get("maxCalls", 20)

    try:
        getToken(config)

        for call in range(0, maxCalls):
            answer = tick(prefix)

            if (answer.get("moreDue") or "N").strip() != "Y":
                break
        else:
            log(f"Still more due after {maxCalls} calls: the next tick goes on")
    except Exception as e:
        log(f"Tick failed: {e}")
        return 8

    return 0


sys.exit(main())
