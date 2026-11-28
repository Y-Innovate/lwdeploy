# Registers the application's API with LWW: uploads the spec, parses it
# with its path prefix and installs every method of every path. The spec's
# file name (api.yaml) and the path prefix (api.pathPrefix, by default
# /<folder.name>/API/v1) are in lwwApp.yaml next to this script; a target in
# runtimeTargets.yaml can overrule them with its own "api:".
#
# python processYAML.py [target] [--list] [--debug]
#   Host and sign-in come from runtimeTargets.yaml (runtimeTarget.py); the
#   spec is read on the host from the target's remoteOASDir.
import json
import lwwApp
import runtimeTarget
import sys

from urllib.parse import quote
from Globals import Globals
from MyRequests import MyRequests

parser = runtimeTarget.argParser("Register the application's API with an LWWAPI server")
args = parser.parse_args()

target = runtimeTarget.useTarget(args, "/LWWAPI/API")

API_YAML, API_PATH_PREFIX = lwwApp.require("api", lwwApp.load(target)["api"], "yaml", "pathPrefix")

if not target.get("remoteOASDir"):
    sys.exit(f"Target '{target['name']}' has no remoteOASDir")

print(f"Registering {API_YAML} on {target['name']} ({target['host']})")

runtimeTarget.signIn(target)

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
    data['YAMLName'] = f"{target['remoteOASDir'].rstrip('/')}/{API_YAML}"

    resppost = MyRequests.post(f"{Globals.pathPrefix}/APIYAML", data)

    if (resppost.status_code == 201 or resppost.status_code == 200):
        print(f"{resppost.status_code} {resppost.text}")

        myYAML = json.loads(resppost.text)

        data = {}
        data['ID_APIYAML'] = myYAML['ID_APIYAML']
        data['APIPathPrefix'] = API_PATH_PREFIX

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