# The LWW host a script talks to, and how it signs in, from runtimeTargets.yaml
# next to this script (gitignored, see runtimeTargets.example.yaml).
#
# Every script takes the same options:
#   python python/<script>.py [target] [--list] [--config <file>] [--debug]
# Without a target the config's "default" is used; --list shows the targets.
#
# This file is the same in petshop-backend, lwdeploy and ctflww; keep them
# in step.
#
# Usage in a script:
#   parser = runtimeTarget.argParser("What the script does")
#   args = parser.parse_args()
#   target = runtimeTarget.useTarget(args, "/LWWAPI/API")
#   runtimeTarget.signIn(target)
import argparse
import json
import os
import requests
import sys
import yaml

from getpass import getpass
from pathlib import Path
from Globals import Globals
from MyRequests import MyRequests

scriptDir = Path(__file__).resolve().parent

# Token path of the LWW Admin API, for targets with auth: password
LWWAPI_TOKEN_PATH = "/LWWAPI/API/token"

def argParser(description):
    """An ArgumentParser with the target options; a script can add its own."""
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("target", nargs="?", help="name of the target in the config file (default: the config's 'default')")
    parser.add_argument("-c", "--config", default=str(scriptDir / "runtimeTargets.yaml"), help="config file (default: %(default)s)")
    parser.add_argument("-l", "--list", action="store_true", help="list the configured targets and exit")
    parser.add_argument("-d", "--debug", action="count", default=0, help="print requests and responses")
    return parser

def loadTarget(configPath, targetName=None, listTargets=False):
    """Returns the target targetName (or the config's default) of the config
    file, with its name in "name". Exits after listing the targets when
    listTargets is set, and when the config or target isn't usable."""
    if not os.path.isfile(configPath):
        sys.exit(f"Config file {configPath} not found; copy runtimeTargets.example.yaml to it and fill it in")

    with open(configPath, "r") as configFile:
        config = yaml.safe_load(configFile) or {}

    targets = config.get("targets") or {}

    if listTargets:
        for name, t in targets.items():
            marker = " (default)" if name == config.get("default") else ""
            print(f"{name}{marker}: {t.get('host')} [{t.get('auth', 'password')}]")
        sys.exit(0)

    targetName = targetName or config.get("default")

    if not targetName:
        sys.exit(f"No target given and no default in {configPath}; choose one of: {', '.join(targets)}")

    if targetName not in targets:
        sys.exit(f"Unknown target '{targetName}'; choose one of: {', '.join(targets)}")

    target = targets[targetName]

    if not target.get("host"):
        sys.exit(f"Target '{targetName}' has no host")

    target["name"] = targetName

    return target

def useTarget(args, pathPrefix):
    """Loads the target chosen in args (or the default one) and sets Globals
    for it. Exits for --list, or when the config or target isn't usable."""
    target = loadTarget(args.config, args.target, args.list)

    Globals.myHost = target["host"].rstrip("/")
    Globals.myBasepath = ""
    Globals.pathPrefix = pathPrefix
    Globals.myDebug = args.debug
    Globals.myCreds = None
    Globals.myBearer = ""
    Globals.s = requests.sessions.Session()
    # Extra headers sent with every request, e.g. a Cloudflare Access cookie
    Globals.s.headers.update(target.get("headers") or {})

    Globals.target = target

    return target

def signIn(target, tokenPath=None):
    """Gets a bearer token for the target, kept in Globals for MyRequests.

    auth: entra    - the Entra client credentials of credsFile (default
                     ~/.creds) at tokenUrl.
    auth: password - the target's userid (or one asked for) and its
                     password, through POST tokenPath: the given one (the
                     app's own /token), else the target's tokenPath, else
                     the LWW Admin API's.
    The credentials stay in Globals, so MyRequests can get a new token when
    the old one expires.
    """
    auth = target.get("auth", "password")

    if auth == "entra":
        # Client credentials from a JSON file: client_id, client_secret, scope, grant_type
        if not target.get("tokenUrl"):
            sys.exit(f"Target '{target['name']}' has auth entra but no tokenUrl")

        credsFile = os.path.expanduser(target.get("credsFile", "~/.creds"))

        with open(credsFile, "r") as credfile:
            Globals.myCreds = json.load(credfile)

        MyRequests.getBearerToken(target["tokenUrl"])
    elif auth == "password":
        userid = target.get("userid") or input("Give your userid: ")
        passwd = getpass(f"Give the password of {userid}: ")
        Globals.myCreds = (userid, passwd)

        MyRequests.getBearerToken(tokenPath or target.get("tokenPath", LWWAPI_TOKEN_PATH))
    else:
        sys.exit(f"Target '{target['name']}' has unknown auth '{auth}' (use 'password' or 'entra')")
