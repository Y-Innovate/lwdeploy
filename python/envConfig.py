# The values of one environment: envs/<env>.yaml, with the site's own values
# from envs/<env>.local.yaml (gitignored) on top. Read by build.py,
# deploy.py and profileUSS.py.
#
# Values may refer to each other with {{NAME}} (SCHEMA: LWD{{DB}}); load()
# resolves those. USERID is the userid running the script, unless an env
# file sets it, so BUILDHLQ: '{{USERID}}.LWD' gives everyone their own build
# libraries. A value with a <placeholder> left in it stops the script: set
# it in envs/<env>.local.yaml. profileUSS.py renders every value, so any
# placeholder stops it; build.py and deploy.py only stop for the values
# they need themselves (require).
#
# Usage in a script:
#   values = envConfig.load("t01")
#   values["TGTHLQ"]
import os
import re
import sys
import yaml

from pathlib import Path
from jinja2 import BaseLoader, Environment, StrictUndefined, UndefinedError

ROOT = Path(__file__).resolve().parent.parent

# Default environment of build.py and deploy.py when none is given
DEFAULT_ENV = os.environ.get("LWD_ENV", "t01")


def userid():
    """The userid running the script (os.getlogin needs a terminal)."""
    try:
        return os.getlogin()
    except OSError:
        return os.environ.get("USER") or os.environ.get("LOGNAME") or ""


def envFile(env):
    return ROOT / "envs" / f"{env.lower()}.yaml"


def placeholdersIn(values, keys=None):
    """The keys (of keys, else all) whose value still has a <placeholder>."""
    return sorted(k for k, v in values.items()
                  if (keys is None or k in keys)
                  and isinstance(v, str) and re.search(r"<[^<>]+>", v))


def loadFile(envfile, resolve=True, allowPlaceholders=False):
    """The values of envfile with those of its .local.yaml on top; with
    resolve, every {{NAME}} in them filled in. Stops when a value still has
    a <placeholder>, unless allowPlaceholders."""
    envfile = Path(envfile)

    if not envfile.is_file():
        sys.exit(f"Environment file {envfile} not found")

    with open(envfile, "r") as f:
        values = yaml.safe_load(f) or {}

    localfile = envfile.with_suffix(".local.yaml")
    if localfile.is_file():
        with open(localfile, "r") as f:
            values.update(yaml.safe_load(f) or {})

    values.setdefault("USERID", userid())

    placeholders = [] if allowPlaceholders else placeholdersIn(values)
    if placeholders:
        sys.exit(f"{envfile.name}: still placeholders for {', '.join(placeholders)}; "
                 f"set them in {localfile}")

    return resolveRefs(values, envfile.name) if resolve else values


def resolveRefs(values, source="environment"):
    """Fills in {{NAME}} in the values, until none is left."""
    jinja = Environment(loader=BaseLoader, undefined=StrictUndefined)
    out = dict(values)

    for _ in range(10):
        changed = False
        for key, value in out.items():
            if isinstance(value, str) and "{{" in value:
                try:
                    new = jinja.from_string(value).render(out)
                except UndefinedError as e:
                    sys.exit(f"{source}: {key}: {e.message}")
                if new != value:
                    out[key] = new
                    changed = True
        if not changed:
            return out

    sys.exit(f"{source}: values keep referring to each other")


def load(env):
    """The resolved values of environment env (t01, T02, ...); require()
    checks the ones a script needs for placeholders."""
    return loadFile(envFile(env), allowPlaceholders=True)


def require(values, *keys):
    """The values of keys; exits naming the ones the env file lacks or that
    still have a <placeholder>."""
    missing = [k for k in keys if k not in values]
    if missing:
        sys.exit(f"Environment {values.get('ENV', '?')} lacks {', '.join(missing)}; "
                 f"add them to envs/<env>.yaml or envs/<env>.local.yaml")
    placeholders = placeholdersIn(values, keys)
    if placeholders:
        sys.exit(f"Environment {values.get('ENV', '?')}: still placeholders for "
                 f"{', '.join(placeholders)}; set them in envs/<env>.local.yaml")
    return [values[k] for k in keys]
