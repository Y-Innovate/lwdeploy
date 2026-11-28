# Uploads LWWAdmin/ to the application's folder in LWW's file system,
# through the LWW Admin API. The folder, its transaction and default page,
# and the files to keep on LWW are in lwwApp.yaml next to this script; a
# target in runtimeTargets.yaml can overrule them. This script has nothing
# of its own application in it, so other LWW apps can use it as it is.
#
# python uploadLWW.py [target] [--list] [--debug] [--keep] [--dry-run]
#   Creates the folder (folder.id) if it doesn't exist yet, then
#   creates the folders and sends the files of LWWAdmin/ that are new or
#   changed: committed files whose git hash differs from the "custom" field
#   on LWW, and files that are added, changed or untracked in the working
#   tree. Then each folder on LWW is made to match the local one: files on
#   LWW that aren't in the local folder are deleted. That removes deleted
#   files, also when the deletion is committed already, and the hashed files
#   of earlier builds in assets/, also builds that were never committed.
#   Subfolders on LWW that aren't here are reported, not deleted, and so
#   are the files of "keep:" in lwwApp.yaml and in the target in
#   runtimeTargets.yaml: files that belong on LWW but not in git, such as
#   the single sign-on configuration.
#   Host and sign-in come from runtimeTargets.yaml (runtimeTarget.py).
#
# Options: [target] --list --debug, and
#   --keep      don't delete files on LWW that aren't in LWWAdmin/
#   --dry-run   only show what would be created, sent and deleted
#   --rename    give the existing folder (folder.id) the name folder.name;
#               without it the upload stops when the folder on LWW has
#               another name (lwdeploy: /lwd became /lwdeploy)
#
# A hidden file .<name> next to the file or folder <name> overrules fields of
# the payload: "newFile:" for files, "newFolder:" for folders. The files in
# LWWAdmin/API/v1 are placeholders, one per API path, whose .<name> sets the
# CICS transaction of the path (docs/04-api.md, Access).
import base64
import json
import os
import re
import subprocess
import sys
import yaml
import lwwApp
import runtimeTarget

from Globals import Globals
from MyRequests import MyRequests

parser = runtimeTarget.argParser("Upload LWWAdmin/ to the application's folder on an LWWAPI server")
parser.add_argument("-k", "--keep", action="store_true", help="don't delete files on LWW that aren't in LWWAdmin/")
parser.add_argument("-n", "--dry-run", action="store_true", help="only show what would be created, sent and deleted")
parser.add_argument("--rename", action="store_true", help="give the existing folder folder.id the name folder.name of lwwApp.yaml")
args = parser.parse_args()

target = runtimeTarget.useTarget(args, "/LWWAPI/API")

print(f"Uploading to {target['name']} ({target['host']}){' - dry run, nothing changes' if args.dry_run else ''}")

app = lwwApp.load(target)
folder = app["folder"]

# The folder in the root of LWW's file system; FOLDER_TRAN is the
# transaction of the folder itself (route folders and API paths set their
# own in their .name files); DEFAULT_PAGE_ID is index.html of the web UI,
# with this fixed ID in LWWAdmin/.index.html
FOLDER_ID, FOLDER_NAME, FOLDER_TRAN, DEFAULT_PAGE_ID = lwwApp.require(
    "folder", folder, "id", "name", "transaction", "defaultPageId")
# Where LWW sends a request for the folder without a session; optional
LOGIN_REDIRECT_ID = folder.get("loginRedirectId")
# Files that live on LWW only and are never deleted by the upload, although
# LWWAdmin/ doesn't have them: paths without a leading / are in the folder
KEEP_ON_LWW = {k if k.startswith("/") else f"/{FOLDER_NAME}/{k}" for k in app["keep"]}

dir = str(runtimeTarget.scriptDir.parent / app["sourceDir"])

runtimeTarget.signIn(target)

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
    # The path on LWW of a local folder: LWWAdmin/API/v1 is /<folder>/API/v1
    return f"/{FOLDER_NAME}{someDir[len(dir):]}"

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

respget = MyRequests.get(f"/LWWAPI/Admin/folders/{FOLDER_ID}")

if respget.status_code == 404 and args.dry_run:
    sys.exit(f"/{FOLDER_NAME} doesn't exist yet: a dry run has nothing to compare with")
elif respget.status_code == 404:
    print(f"Create dir /{FOLDER_NAME}")

    data = {}
    data['folderId'] = FOLDER_ID
    data['parentFolderId'] = "ROOT"
    data['folderName'] = FOLDER_NAME
    data['path'] = f"/{FOLDER_NAME}"
    data['generateId'] = "N"
    data['defaultTran'] = FOLDER_TRAN

    resppost = MyRequests.post("/LWWAPI/Admin/folders", data)
    checkResponse(resppost)
else:
    checkResponse(respget)

    # The folder may have another name on LWW, when folder.name changed. It
    # is renamed only on request: whether LWW then also moves the paths of
    # the folders and files in it is not known, so check the result on LWW
    # afterwards. The field names of the GET response are taken from the
    # request.
    current = respget.json()
    oldPath = current.get("path") or (current.get("folderName") and f"/{current['folderName']}")
    if not oldPath:
        print(f"Can't tell the name of folder {FOLDER_ID} from: {respget.text[:200]}")
    elif oldPath != f"/{FOLDER_NAME}":
        if not args.rename or args.dry_run:
            sys.exit(f"Folder {FOLDER_ID} is {oldPath}, not /{FOLDER_NAME}: "
                     "run again with --rename (and without --dry-run) to change it")

        print(f"Rename {oldPath} to /{FOLDER_NAME}")

        data = {}
        data['folderId'] = FOLDER_ID
        data['generateId'] = "N"
        data['parentFolderId'] = "ROOT"
        data['folderName'] = FOLDER_NAME
        data['path'] = f"/{FOLDER_NAME}"
        data['defaultTran'] = FOLDER_TRAN
        if current.get('defaultWebpageId'):
            data['defaultWebpageId'] = current['defaultWebpageId']
        if current.get('loginRedirectWebpageId'):
            data['loginRedirectWebpageId'] = current['loginRedirectWebpageId']

        respput = MyRequests.put(f"/LWWAPI/Admin/folders/{FOLDER_ID}", data)
        checkResponse(respput)

doDir(dir, FOLDER_ID)

# The default page of the folder can only point at index.html once that
# exists on LWW, and the login redirect at its page, so both are set after
# the upload: when the folder doesn't have them yet, or doesn't run under
# FOLDER_TRAN (any more). The name of the transaction field in the GET
# response is taken from the request.
if os.path.isfile(os.path.join(dir, "index.html")) and not args.dry_run:
    respget = MyRequests.get(f"/LWWAPI/Admin/folders/{FOLDER_ID}")
    checkResponse(respget)

    tran = re.search(r'"defaultTran"\s*:\s*"(\w*)"', respget.text)
    if tran is None:
        print(f"Can't tell the transaction of /{FOLDER_NAME} from: {respget.text[:200]}")
    wrongTran = tran is not None and tran.group(1) != FOLDER_TRAN
    noRedirect = LOGIN_REDIRECT_ID and f'"{LOGIN_REDIRECT_ID}"' not in respget.text

    if f'"{DEFAULT_PAGE_ID}"' not in respget.text or wrongTran or noRedirect:
        print(f"Set the default page of /{FOLDER_NAME} to {DEFAULT_PAGE_ID}, "
              + (f"its login redirect to {LOGIN_REDIRECT_ID}, " if LOGIN_REDIRECT_ID else "")
              + f"its transaction to {FOLDER_TRAN}")

        data = {}
        data['folderId'] = FOLDER_ID
        data['generateId'] = "N"
        data['parentFolderId'] = "ROOT"
        data['folderName'] = FOLDER_NAME
        data['path'] = f"/{FOLDER_NAME}"
        data['defaultTran'] = FOLDER_TRAN
        data['defaultWebpageId'] = DEFAULT_PAGE_ID
        if LOGIN_REDIRECT_ID:
            data['loginRedirectWebpageId'] = LOGIN_REDIRECT_ID

        respput = MyRequests.put(f"/LWWAPI/Admin/folders/{FOLDER_ID}", data)
        checkResponse(respput)
