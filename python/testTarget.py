# The target of the testIteration*.py scripts: the host from
# runtimeTargets.yaml next to this script, as uploadLWW.py has it (see
# runtimeTargets.example.yaml). The scripts sign in themselves, with the
# userids and passphrases they ask for.
#
# python testIterationN.py [--target <name>] ...
#   Without --target, the config's "default" is used. --list shows the
#   targets.
import requests
import sys
import yaml

from pathlib import Path
from Globals import Globals

CONFIG = Path(__file__).resolve().parent / "runtimeTargets.yaml"


def _takeOption(names, hasValue=True):
    # Takes an option out of sys.argv, so the scripts see only their own
    # arguments. Returns its value (True for a flag), or None.
    for i, arg in enumerate(sys.argv[1:], start=1):
        for name in names:
            if hasValue and arg.startswith(f"{name}="):
                del sys.argv[i]
                return arg.split("=", 1)[1]
            if arg == name:
                if not hasValue:
                    del sys.argv[i]
                    return True
                if i + 1 >= len(sys.argv):
                    sys.exit(f"{name} needs a value")
                value = sys.argv[i + 1]
                del sys.argv[i:i + 2]
                return value
    return None


def useTarget(pathPrefix="/lwdeploy/API/v1"):
    """Sets Globals for the target chosen with --target, or the default one."""
    if not CONFIG.is_file():
        sys.exit(f"Config file {CONFIG} not found; copy runtimeTargets.example.yaml to it and fill it in")

    with open(CONFIG, "r") as configFile:
        config = yaml.safe_load(configFile) or {}

    targets = config.get("targets") or {}

    if _takeOption(("-l", "--list"), hasValue=False):
        for name, t in targets.items():
            marker = " (default)" if name == config.get("default") else ""
            print(f"{name}{marker}: {t.get('host')}")
        sys.exit(0)

    targetName = _takeOption(("-t", "--target")) or config.get("default")

    if not targetName:
        sys.exit(f"No --target given and no default in {CONFIG}; choose one of: {', '.join(targets)}")

    if targetName not in targets:
        sys.exit(f"Unknown target '{targetName}'; choose one of: {', '.join(targets)}")

    target = targets[targetName]

    if not target.get("host"):
        sys.exit(f"Target '{targetName}' has no host")

    print(f"Testing against {targetName} ({target['host']})")

    Globals.target = target
    Globals.myHost = target["host"].rstrip("/")
    Globals.pathPrefix = pathPrefix
    Globals.myCreds = None
    Globals.myBearer = ""
    Globals.myDebug = 0
    Globals.s = requests.sessions.Session()
    # Extra headers sent with every request, e.g. a Cloudflare Access cookie
    Globals.s.headers.update(target.get("headers") or {})

    return target
