# Reads lwwApp.yaml: what this repository puts on LWW (the folder, the files
# to keep there, the API spec). Used by uploadLWW.py and processYAML.py.
# A target in runtimeTargets.yaml can overrule fields of "folder" and "api"
# with its own "folder:" and "api:", and add files with its own "keep:".
import sys

import yaml

import runtimeTarget

APP_FILE = runtimeTarget.scriptDir / "lwwApp.yaml"


def load(target):
    """lwwApp.yaml with the target's overrides on top, as a dict with
    sourceDir, folder, keep and api. api.pathPrefix defaults to
    /<folder.name>/API/v1, where the API placeholders of sourceDir go."""
    if not APP_FILE.is_file():
        sys.exit(f"{APP_FILE} not found: it names the LWW folder and API of this repository")

    with open(APP_FILE, "r") as f:
        app = yaml.safe_load(f) or {}

    folder = {**(app.get("folder") or {}), **(target.get("folder") or {})}
    api = {**(app.get("api") or {}), **(target.get("api") or {})}

    if folder.get("name") and not api.get("pathPrefix"):
        api["pathPrefix"] = f"/{folder['name']}/API/v1"

    return {
        "sourceDir": app.get("sourceDir", "LWWAdmin"),
        "folder": folder,
        "keep": list(app.get("keep") or []) + list(target.get("keep") or []),
        "api": api,
    }


def require(section, values, *keys):
    """The values of keys in values (the section of lwwApp.yaml called
    section); stops when any is missing."""
    missing = [k for k in keys if not values.get(k)]

    if missing:
        sys.exit(f"{APP_FILE.name}: {section} lacks {', '.join(missing)}")

    return [values[k] for k in keys]
