# Uploads LWWAdmin/ to the /lwdeploy folder of LWW's file system, through the LWW
# Admin API. A copy of uploadLWW.py of ctfdlww.
#
# python uploadLWW.py
#   Creates /lwdeploy (folder ID LWD_FOLDER_ID) if it doesn't exist yet, then
#   creates the folders and sends the files of LWWAdmin/ that are new or
#   changed: committed files whose git hash differs from the "custom" field
#   on LWW, and files that are added, changed or untracked in the working
#   tree. Then each folder on LWW is made to match the local one: files on
#   LWW that aren't in the local folder are deleted. That removes deleted
#   files, also when the deletion is committed already, and the hashed files
#   of earlier builds in assets/, also builds that were never committed.
#   Subfolders on LWW that aren't here are reported, not deleted, and so
#   are the files of KEEP_ON_LWW and of the target's "keep:" list in
#   runtimeTargets.yaml: files that belong on LWW but not in git, such as
#   the single sign-on configuration.
#   Host and sign-in come from runtimeTargets.yaml (see the example file).
#
# Options: [target] --list --debug, and
#   --keep      don't delete files on LWW that aren't in LWWAdmin/
#   --dry-run   only show what would be created, sent and deleted
#   --rename    give the existing folder its new name (/lwd became
#               /lwdeploy on 2026-11-15)
#
# A hidden file .<name> next to the file or folder <name> overrules fields of
# the payload: "newFile:" for files, "newFolder:" for folders. The files in
# LWWAdmin/API/v1 are placeholders, one per API path, whose .<name> sets the
# CICS transaction of the path: LWDU user, LWDA admin, LWDQ scheduler, LWDJ result
# step, and LWW's own LWBL
# for /token.
import base64
import json
import os
import re
import requests
import subprocess
import sys
import yaml
import argparse

from getpass import getpass
from pathlib import Path
from Globals import Globals
from MyRequests import MyRequests

# Hosts and sign-in details live in runtimeTargets.yaml next to this script,
# see runtimeTargets.example.yaml. Usage: python uploadLWW.py [target] [--list] [--debug]

scriptDir = Path(__file__).resolve().parent

parser = argparse.ArgumentParser(description="Upload LWWAdmin/ to the /lwdeploy folder of an LWWAPI server")
parser.add_argument("target", nargs="?", help="name of the target in the config file (default: the config's 'default')")
parser.add_argument("-c", "--config", default=str(scriptDir / "runtimeTargets.yaml"), help="config file (default: %(default)s)")
parser.add_argument("-l", "--list", action="store_true", help="list the configured targets and exit")
parser.add_argument("-d", "--debug", action="count", default=0, help="print requests and responses")
parser.add_argument("-k", "--keep", action="store_true", help="don't delete files on LWW that aren't in LWWAdmin/")
parser.add_argument("-n", "--dry-run", action="store_true", help="only show what would be created, sent and deleted")
parser.add_argument("--rename", action="store_true", help="give an existing folder LWD_FOLDER_ID the name LWD_FOLDER_NAME (it was /lwd until 2026-11-15)")
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

print(f"Uploading to {targetName} ({target['host']}){' - dry run, nothing changes' if args.dry_run else ''}")

Globals.myHost = target["host"].rstrip("/")
Globals.myBasepath = ""
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

# The /lwdeploy folder in the root of LWW's file system
LWD_FOLDER_ID = "LD000000"
LWD_FOLDER_NAME = "lwdeploy"
# The /lwdeploy folder itself runs under LWD's user transaction LWDU, as the
# route folders of the web UI do (their .name files). What must load before
# sign-in has its own transaction in its .name file: LWD's public LWDP for
# index.html, assets/ and the login folder, LWW's own LWBL for LWW's sign-in
# pages. The API paths get LWDU, LWDA, LWDQ or LWDJ from their placeholders,
# and LWBL for /token (docs/04-api.md, Access).
LWD_FOLDER_TRAN = "LWDU"
# index.html of the web UI, with this fixed ID in LWWAdmin/.index.html: the
# page /lwdeploy/ shows
LWD_DEFAULT_PAGE_ID = "LD000001"
# redirect_to_login.html, with this fixed ID in LWWAdmin/.redirect_to_login.html:
# where LWW sends a request for /lwdeploy without a session, as the route
# folders do (since 2026-11-15, when the folder moved to LWDU)
LWD_LOGIN_REDIRECT_ID = "LD000003"
# Files that live on LWW only and are never deleted by the upload, although
# LWWAdmin/ doesn't have them: they hold settings that stay out of git. More
# per target with "keep:" (a list of paths like these) in runtimeTargets.yaml.
KEEP_ON_LWW = {
    f"/{LWD_FOLDER_NAME}/sso_config.json",  # LWW's single sign-on (Entra) configuration
} | set(target.get("keep") or [])

dir = str(scriptDir.parent / "LWWAdmin")

mediaTypes = {
    "js": "text/javascript",
    "jsx": "text/javascript",
    "png": "image/png",
    "md": "text/markdown",
    "json": "application/json",
    "gif": "image/gif",
    "css": "text/css",
    "less": "text/css",
    "html": "text/html",
    "svg": "image/svg+xml",
    "woff2": "font/woff2",
}

def runGit(cmdline):
    rslt = subprocess.run([cmdline], shell=True, cwd=dir, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    if rslt.returncode:
        print(rslt.stdout)
        print(rslt.stderr)
        sys.exit(f"{cmdline} returned {rslt.returncode}")

    return rslt.stdout.decode(encoding='utf-8').splitlines()

def checkResponse(resp, allowed=()):
    if resp.status_code >= 400 and resp.status_code not in allowed:
        raise Exception(f"status code {resp.status_code} {resp.text}")

    if Globals.myDebug > 0:
        print(f"{resp.status_code} {resp.text}")

def lwwPath(someDir):
    # The path on LWW of a local folder: LWWAdmin/API/v1 is /lwdeploy/API/v1
    return f"/{LWD_FOLDER_NAME}{someDir[len(dir):]}"

def applyOverrides(data, path, key):
    # A hidden file .<name> next to the file or folder <name> overrules fields of the payload
    overrideFileName = os.path.join(os.path.dirname(path), f".{os.path.basename(path)}")

    if (os.path.isfile(overrideFileName)):
        with open(overrideFileName, 'r') as overrideFile:
            overrides = yaml.safe_load(overrideFile)

        if overrides and key in overrides and overrides[key]:
            for k in overrides[key]:
                data[k] = overrides[key][k]

def overrideChanged(relpath):
    # True when the hidden override file .<name> of the file or folder <name> is changed,
    # added or deleted in the working tree, so <name> must be sent again
    x = relpath.rfind("/")

    overrideRelpath = f"{relpath[:x+1]}.{relpath[x+1:]}"

    return overrideRelpath in workingTreeUpdates or overrideRelpath in workingTreeDeletes

def folderData(someDir, id, parentId, custom):
    data = {}
    if not id:
        data['folderId'] = ""
        data['generateId'] = "Y"
    else:
        data['folderId'] = id
        data['generateId'] = "N"
    data['parentFolderId'] = parentId
    data['folderName'] = os.path.basename(someDir)
    data['path'] = lwwPath(someDir)
    data['custom'] = custom

    applyOverrides(data, someDir, 'newFolder')

    return data

def createDir(someDir, parentId, custom):
    print(f"Create dir {someDir[len(dir)+1:]}")

    if args.dry_run:
        return None

    resppost = MyRequests.post("/LWWAPI/Admin/folders", folderData(someDir, None, parentId, custom))
    checkResponse(resppost)

    return json.loads(resppost.text)['folderId']

def updateDir(someDir, id, parentId, custom):
    print(f"Update dir {someDir[len(dir)+1:]}")

    if args.dry_run:
        return

    respput = MyRequests.put(f"/LWWAPI/Admin/folders/{id}", folderData(someDir, id, parentId, custom))
    checkResponse(respput)

def uploadFile(f, id, parentId, custom, found):
    _custom = custom

    x = re.search("[^\\/]*\\.([^.]*)$", f)

    mediaType = "text/plain"

    if x and x.group(1) in mediaTypes:
        mediaType = mediaTypes[x.group(1)]

    relpath = f[len(dir)+1:]
    fileName = os.path.basename(f)

    if relpath in workingTreeUpdates:
        calculatedHash = runGit(f"git hash-object '{relpath}'")[0]

        if calculatedHash == found and not overrideChanged(relpath):
            return

        _custom = calculatedHash

    print(f"Update file {id} {mediaType} {relpath} {_custom}")

    if args.dry_run:
        return

    with open(f, 'rb') as file:
        fileContents = file.read()

    fileContentsB64 = base64.b64encode(fileContents).decode("ascii")

    newFile = {}
    if not id:
        newFile['fileId'] = ""
        newFile['generateId'] = "Y"
    else:
        newFile['fileId'] = id
        newFile['generateId'] = "N"
    newFile['fileType'] = "W"
    newFile['folderId'] = parentId
    newFile['fileName'] = fileName
    newFile['mediaType'] = mediaType
    newFile['preventCache'] = "N"
    newFile['storeBinary'] = "Y"
    newFile['custom'] = _custom

    applyOverrides(newFile, f, 'newFile')

    resppost = MyRequests.post("/LWWAPI/Admin/files", None, {'jsondata': (None, json.dumps(newFile)), 'contents': (None, fileContentsB64)})
    checkResponse(resppost)

def deleteFile(id, fileName):
    print(f"Delete file {id} {fileName}")

    if args.dry_run:
        return

    respdelete = MyRequests.delete(f"/LWWAPI/Admin/files/{id}")
    checkResponse(respdelete, (404,))

def gitTree(relDir):
    # Files and folders of relDir in the last commit; none if nothing is committed yet
    gitFiles = []
    gitFolders = []

    if not commitHash:
        return gitFiles, gitFolders

    # ls-tree run from the content root also works for folders that were deleted
    # from the working tree (their files still need deleting on the server)
    if len(relDir) > 0:
        lines = runGit(f"git ls-tree {commitHash} -- '{relDir}/'")
        # ls-tree prints the names with the folder path in front; keep just the names
        lines = [l.replace(f"\t{relDir}/", "\t", 1) for l in lines]
    else:
        lines = runGit(f"git ls-tree {commitHash}")

    prefix = f"{relDir}/" if len(relDir) > 0 else ""

    for l in lines:
        x = re.search("(\\S+)\\s+(\\S+)\\s+(\\S+)\\s+(\\S*)", l)

        if not x:
            raise Exception(f"error parsing ls-tree output: {l}")

        if x.group(2) == "blob":
            gitFiles.append({"fileName": x.group(4), "hash": x.group(3), "relpath": prefix + x.group(4)})
        elif x.group(2) == "tree":
            gitFolders.append({"folderName": x.group(4), "hash": x.group(3), "dir": prefix + x.group(4)})

    return gitFiles, gitFolders

def doDir(someDir, parentId):
    # parentId is None for a folder a dry run would have created
    respget = MyRequests.get(f"/LWWAPI/Admin/files?folderId={parentId}") if parentId else None

    if respget is None:
        folderContents = []
    elif respget.status_code == 200:
        folderContents = json.loads(respget.text)['folderContents']
    elif respget.status_code == 404:
        folderContents = []
    else:
        raise Exception(f"{respget.status_code} {respget.text}")

    relDir = someDir[len(dir)+1:]

    gitFiles, gitFolders = gitTree(relDir)

    # Folders that only exist in the working tree
    for neededDir in neededDirs:
        if os.path.dirname(neededDir) == relDir:
            folderName = os.path.basename(neededDir)

            if not any(d['folderName'] == folderName for d in gitFolders):
                gitFolders.append({"folderName": folderName, "hash": "", "dir": neededDir})

    # Files that are new or changed in the working tree
    for n in range(0, len(workingTreeUpdates)):
        if someDir == workingTreeUpdatesDirs[n]:
            relpath = workingTreeUpdates[n]

            if not any(f['relpath'] == relpath for f in gitFiles):
                gitFiles.append({"fileName": os.path.basename(relpath), "hash": None, "relpath": relpath})

    gitFiles = [f for f in gitFiles if f['relpath'] not in workingTreeDeletes]

    for f in gitFiles:
        if f['fileName'][0] != ".":
            found = None

            for c in folderContents:
                if c['fileType'] != 'subfolder' and c['fileName'] == f['fileName']:
                    found = c['custom']
                    f['fileId'] = c['fileId']
                    break

            if not 'fileId' in f or f['hash'] != found or f['relpath'] in workingTreeUpdates or overrideChanged(f['relpath']):
                uploadFile(f"{someDir}/{f['fileName']}", f.get('fileId'), parentId, f['hash'], found)

    # Make the folder on LWW match the local one: delete the files that aren't
    # here (any more). Git can't be asked for these: a deletion may be committed
    # already, and the assets of a build that was never committed leave no
    # trace in git when the next build removes them. A folder deleted here
    # entirely has no local files, so all its files go.
    localFiles = set()
    localFolders = set()

    if os.path.isdir(someDir):
        for name in os.listdir(someDir):
            if os.path.isdir(os.path.join(someDir, name)):
                localFolders.add(name)
            else:
                localFiles.add(name)

    for c in folderContents:
        if c['fileType'] == 'subfolder':
            if c['fileName'] not in localFolders and not any(d['folderName'] == c['fileName'] for d in gitFolders):
                print(f"Not in LWWAdmin, left alone: folder {lwwPath(someDir)}/{c['fileName']}")
        elif c['fileName'] not in localFiles:
            if f"{lwwPath(someDir)}/{c['fileName']}" in KEEP_ON_LWW:
                if Globals.myDebug > 0:
                    print(f"Kept, in KEEP_ON_LWW: {lwwPath(someDir)}/{c['fileName']}")
            elif args.keep:
                print(f"Not in LWWAdmin, kept (--keep): {lwwPath(someDir)}/{c['fileName']}")
            else:
                deleteFile(c['fileId'], f"{lwwPath(someDir)}/{c['fileName']}")

    for d in gitFolders:
        if d['folderName'][0] != ".":
            found = None

            for c in folderContents:
                if c['fileType'] == 'subfolder' and c['fileName'] == d['folderName']:
                    found = c['custom']
                    d['folderId'] = c['fileId']
                    break

            if not 'folderId' in d:
                id = createDir(f"{someDir}/{d['folderName']}", parentId, d['hash'])

                doDir(f"{someDir}/{d['folderName']}", id)
            else:
                doDir(f"{someDir}/{d['folderName']}", d['folderId'])

                if d['hash'] != found or overrideChanged(d['dir']):
                    updateDir(f"{someDir}/{d['folderName']}", d['folderId'], parentId, d['hash'])

def computeDirsList(paths):
    # The local folder of each path; adds every folder on the way to neededDirs
    result = []

    for f in paths:
        parts = f.split('/')

        combinedParts = ""

        for n in range(0, len(parts)-1):
            if combinedParts == "":
                combinedParts = parts[n]
            else:
                combinedParts = f"{combinedParts}/{parts[n]}"

            if not combinedParts in neededDirs:
                neededDirs.append(combinedParts)

        if (combinedParts == ""):
            result.append(dir)
        else:
            result.append(f"{dir}/{combinedParts}")

    return result

os.chdir(dir)

# The tree of the last commit that touched LWWAdmin/; empty if there is none yet
outGitLog = runGit("git log -n 1 --format='%T' -- .")
commitHash = outGitLog[0] if outGitLog else None

# Paths relative to LWWAdmin/. --no-renames: a moved file must show up as deleted
# (old place) and added (new place). -uall: untracked files one by one, not their folder.
outWorkTree = runGit("git status -s --no-renames -uall -- .")

workingTreeUpdates = []
workingTreeDeletes = []

for line in outWorkTree:
    status = line[:2]
    path = line[3:].strip('"')

    if "D" in status:
        workingTreeDeletes.append(path)
    elif "A" in status or "M" in status or status == "??":
        workingTreeUpdates.append(path)

neededDirs = []

workingTreeUpdatesDirs = computeDirsList(workingTreeUpdates)
workingTreeDeletesDirs = computeDirsList(workingTreeDeletes)

respget = MyRequests.get(f"/LWWAPI/Admin/folders/{LWD_FOLDER_ID}")

if respget.status_code == 404 and args.dry_run:
    sys.exit(f"/{LWD_FOLDER_NAME} doesn't exist yet: a dry run has nothing to compare with")
elif respget.status_code == 404:
    print(f"Create dir /{LWD_FOLDER_NAME}")

    data = {}
    data['folderId'] = LWD_FOLDER_ID
    data['parentFolderId'] = "ROOT"
    data['folderName'] = LWD_FOLDER_NAME
    data['path'] = f"/{LWD_FOLDER_NAME}"
    data['generateId'] = "N"
    data['defaultTran'] = LWD_FOLDER_TRAN

    resppost = MyRequests.post("/LWWAPI/Admin/folders", data)
    checkResponse(resppost)
else:
    checkResponse(respget)

    # The folder was /lwd until 2026-11-15. Its name is changed only on
    # request: whether LWW then also moves the paths of the folders and files
    # in it is not known yet, so check the result on LWW afterwards. The
    # field names of the GET response are a guess, taken from the request.
    folder = respget.json()
    oldPath = folder.get("path") or (folder.get("folderName") and f"/{folder['folderName']}")
    if not oldPath:
        print(f"Can't tell the name of folder {LWD_FOLDER_ID} from: {respget.text[:200]}")
    elif oldPath != f"/{LWD_FOLDER_NAME}":
        if not args.rename or args.dry_run:
            sys.exit(f"Folder {LWD_FOLDER_ID} is {oldPath}, not /{LWD_FOLDER_NAME}: "
                     "run again with --rename (and without --dry-run) to change it")

        print(f"Rename {oldPath} to /{LWD_FOLDER_NAME}")

        data = {}
        data['folderId'] = LWD_FOLDER_ID
        data['generateId'] = "N"
        data['parentFolderId'] = "ROOT"
        data['folderName'] = LWD_FOLDER_NAME
        data['path'] = f"/{LWD_FOLDER_NAME}"
        data['defaultTran'] = LWD_FOLDER_TRAN
        if folder.get('defaultWebpageId'):
            data['defaultWebpageId'] = folder['defaultWebpageId']
        if folder.get('loginRedirectWebpageId'):
            data['loginRedirectWebpageId'] = folder['loginRedirectWebpageId']

        respput = MyRequests.put(f"/LWWAPI/Admin/folders/{LWD_FOLDER_ID}", data)
        checkResponse(respput)

doDir(dir, LWD_FOLDER_ID)

# The default page of /lwdeploy can only point at index.html once that exists on
# LWW, and the login redirect at redirect_to_login.html, so both are set after
# the upload: when the folder doesn't have them yet, or doesn't run under
# LWD_FOLDER_TRAN (it was LWBL until 2026-11-15). The name
# of the transaction field in the GET response is a guess, taken from the
# request.
if os.path.isfile(os.path.join(dir, "index.html")) and not args.dry_run:
    respget = MyRequests.get(f"/LWWAPI/Admin/folders/{LWD_FOLDER_ID}")
    checkResponse(respget)

    tran = re.search(r'"defaultTran"\s*:\s*"(\w*)"', respget.text)
    if tran is None:
        print(f"Can't tell the transaction of /{LWD_FOLDER_NAME} from: {respget.text[:200]}")
    wrongTran = tran is not None and tran.group(1) != LWD_FOLDER_TRAN
    noRedirect = f'"{LWD_LOGIN_REDIRECT_ID}"' not in respget.text
    if f'"{LWD_DEFAULT_PAGE_ID}"' not in respget.text or wrongTran or noRedirect:
        print(f"Set the default page of /{LWD_FOLDER_NAME} to {LWD_DEFAULT_PAGE_ID}, "
              f"its login redirect to {LWD_LOGIN_REDIRECT_ID}, its transaction to {LWD_FOLDER_TRAN}")

        data = {}
        data['folderId'] = LWD_FOLDER_ID
        data['generateId'] = "N"
        data['parentFolderId'] = "ROOT"
        data['folderName'] = LWD_FOLDER_NAME
        data['path'] = f"/{LWD_FOLDER_NAME}"
        data['defaultTran'] = LWD_FOLDER_TRAN
        data['defaultWebpageId'] = LWD_DEFAULT_PAGE_ID
        data['loginRedirectWebpageId'] = LWD_LOGIN_REDIRECT_ID

        respput = MyRequests.put(f"/LWWAPI/Admin/folders/{LWD_FOLDER_ID}", data)
        checkResponse(respput)
