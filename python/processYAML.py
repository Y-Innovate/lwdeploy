import base64
import requests
import json
import os
import sys
import yaml
import argparse

from getpass import getpass
from pathlib import Path
from urllib.parse import quote
from Globals import Globals
from MyRequests import MyRequests

# Hosts and sign-in details live in runtimeTargets.yaml next to this script (gitignored),
# see runtimeTargets.example.yaml. Usage: python python/processYAML.py [target] [--list] [--debug]

scriptDir = Path(__file__).resolve().parent

parser = argparse.ArgumentParser(description="Upload to an LWWAPI server")
parser.add_argument("target", nargs="?", help="name of the target in the config file (default: the config's 'default')")
parser.add_argument("-c", "--config", default=str(scriptDir / "runtimeTargets.yaml"), help="config file (default: %(default)s)")
parser.add_argument("-l", "--list", action="store_true", help="list the configured targets and exit")
parser.add_argument("-d", "--debug", action="count", default=0, help="print requests and responses")
args = parser.parse_args()

if not os.path.isfile(args.config):
    sys.exit(f"Config file {args.config} not found; copy runtimeTargets.example.yaml to it and fill it in")

with open(args.config, "r") as configFile:
    config = yaml.safe_load(configFile) or {}

targets = config.get("targets") or {}

if args.list:
    for name, t in targets.items():
        marker = " (default)" if name == config.get("default") else ""
        print(f"{name}{marker}: {t.get('host')} [{t.get('auth', 'password')}]")
    sys.exit(0)

targetName = args.target or config.get("default")

if not targetName:
    sys.exit(f"No target given and no default in {args.config}; choose one of: {', '.join(targets)}")

if targetName not in targets:
    sys.exit(f"Unknown target '{targetName}'; choose one of: {', '.join(targets)}")

target = targets[targetName]

if not target.get("host"):
    sys.exit(f"Target '{targetName}' has no host")

Globals.myHost = target["host"].rstrip("/")
Globals.myBasepath = ""
Globals.pathPrefix = "/LWWAPI/API"
Globals.myDebug = args.debug
Globals.s = requests.sessions.Session()
# Extra headers sent with every request, e.g. a Cloudflare Access cookie
Globals.s.headers.update(target.get("headers") or {})

auth = target.get("auth", "password")

if auth == "entra":
    # Client credentials from a JSON file: client_id, client_secret, scope, grant_type
    credsFile = os.path.expanduser(target.get("credsFile", "~/.creds"))

    with open(credsFile, "r") as credfile:
        Globals.myCreds = json.load(credfile)

    MyRequests.getBearerToken(target["tokenUrl"])
elif auth == "password":
    userid = target.get("userid") or input("Give your userid: ")
    passwd = getpass(f"Give the password of {userid}: ")
    Globals.myCreds = (userid, passwd)

    MyRequests.getBearerToken(target.get("tokenPath", "/LWWAPI/API/token"))
else:
    sys.exit(f"Target '{targetName}' has unknown auth '{auth}' (use 'password' or 'entra')")

def getAPIPaths(idAPI):
    # LWW returns at most 20 paths per call; APIPath_start asks for the next page
    myPaths = []
    seenIDs = set()
    uri = f"{Globals.pathPrefix}/APIPath?ID_API={idAPI}"

    while True:
        respget = MyRequests.get(uri)

        # A 404 on a later page means there are no more paths
        if (respget.status_code == 404 and myPaths):
            break

        if (respget.status_code != 200):
            raise Exception(f'status code {str(respget.status_code)} {respget.text}')

        print(f"{respget.status_code} {respget.text}")

        page = json.loads(respget.text).get('APIPath', [])
        # The spec doesn't say whether APIPath_start is inclusive, so skip paths already seen
        newPaths = [p for p in page if p['ID_APIPath'] not in seenIDs]

        if not newPaths:
            break

        myPaths.extend(newPaths)
        seenIDs.update(p['ID_APIPath'] for p in newPaths)

        if (len(page) < 20):
            break

        uri = f"{Globals.pathPrefix}/APIPath?ID_API={idAPI}&APIPath_start={quote(page[-1]['APIPath'], safe='/')}"

    return myPaths

def doStuff():
    data = {}
    data['YAMLName'] = f"{target.get('remoteOASDir')}/lwd_1.0.0.yaml"

    resppost = MyRequests.post(f"{Globals.pathPrefix}/APIYAML", data)

    if (resppost.status_code == 201 or resppost.status_code == 200):
        print(f"{resppost.status_code} {resppost.text}")

        myYAML = json.loads(resppost.text)

        data = {}
        data['ID_APIYAML'] = myYAML['ID_APIYAML']
        data['APIPathPrefix'] = '/lwdeploy/API/v1'

        resppost = MyRequests.post(f"{Globals.pathPrefix}/APIYAMLParse", data)

        if (resppost.status_code == 200):
            print(f"{resppost.status_code} {resppost.text}")

            myPaths = getAPIPaths(myYAML['ID_API'])

            for APIPath in myPaths:
                respget = MyRequests.get(f"{Globals.pathPrefix}/APIMethod?ID_APIPath={APIPath['ID_APIPath']}")

                if (respget.status_code == 200):
                    print(f"{respget.status_code} {respget.text}")

                    myMethods = json.loads(respget.text)

                    for APIMethod in myMethods['APIMethod']:
                        data = {}
                        data['ID_API'] = myYAML['ID_API']
                        data['APIPath'] = APIPath['APIPath']
                        data['APIMethod'] = APIMethod['APIMethod']
                        data['pathWithId'] = APIMethod['pathWithId']

                        resppost = MyRequests.post(f"{Globals.pathPrefix}/APIIST", data)

                        if (resppost.status_code == 200):
                            print(f"{resppost.status_code} {resppost.text}")
                        else:
                            raise Exception(f'status code {str(resppost.status_code)} {resppost.text}')
                elif (respget.status_code != 404):
                    raise Exception(f'status code {str(respget.status_code)} {respget.text}')
        else:
            raise Exception(f'status code {str(resppost.status_code)} {resppost.text}')
    else:
        raise Exception(f'status code {str(resppost.status_code)} {resppost.text}')

doStuff()