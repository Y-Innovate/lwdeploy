"""Generate openapi/lwd_1.0.0.yaml (public contract, CTF style) and the
endpoint tables of docs/04-api.md (written to python/api-tables.md, to paste)
from one list of operations. Only operations built so far (genlww.OPS) refer
to their LWW processing steps. Run from the repository root:
python python/genoas.py, then python python/genlww.py."""
import os
import sys
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "python"))
from genlww import OPS as BUILT  # noqa: E402

OUT_YAML = os.path.join(ROOT, "openapi", "lwd_1.0.0.yaml")
OUT_MD = os.path.join(ROOT, "python", "api-tables.md")
TS_EX = "2026-01-01-00.00.00.000000"

# ---------------------------------------------------------------- fields
F = {}


def s(name, n, desc, **kw):
    d = {"type": "string", "minLength": 0, "maxLength": n, "description": desc}
    d.update(kw)
    F[name] = d


def i(name, desc):
    F[name] = {"type": "integer", "description": desc}


def ts(name, desc):
    s(name, 26, desc, example=TS_EX)


def yn(name, desc):
    s(name, 1, desc)


s("retCode", 2, "Return code", example="00")
s("reasonCode", 2, "Reason code", example="00")
s("infoMessage", 72, "Result text")
s("username", 8, "RACF userid")
s("password", 100, "RACF passphrase; never logged or stored")
s("token", 1024, "Access token")

s("userID", 8, "RACF userid")
s("email", 254, "Email address from RACF (WORKATTR WAEMAIL); empty = no mail")
yn("notifyApprove", "Y: mail when an approval waits for me")
yn("notifyOwn", "Y: mail when my deployment is decided or ends")
yn("notifyApp", "Y: mail when a deployment of an application I own ends")
yn("isAdmin", "Y: administrator")
i("approvalsWaiting", "Deployments waiting for my approval")
yn("isMember", "Y: in the access group")
yn("isOwner", "Y: in the owner group")
yn("isApprover", "Y: in the approver group of at least one environment")
yn("canDeploy", "Y: the user may request deployments here")
yn("canApprove", "Y: the user may approve here")
yn("canCancel", "Y: the user may cancel this deployment now")
yn("canRetry", "Y: the user may retry or continue this deployment now")

i("appID", "Application key")
s("appCode", 8, "Short code, upper case; ${LWDAPP} in JCL")
s("appName", 60, "Name")
s("appDescription", 1000, "Description")
s("accessGroup", 8, "RACF group of members, from RACFGRP")
s("ownerGroup", 8, "RACF group of owners, from RACFGRP")

i("envID", "Environment key; 0 = none")
s("envCode", 8, "Short code, upper case; ${LWDENV} in JCL")
s("envName", 60, "Name")
s("envDescription", 1000, "Description")
i("sortOrder", "Position in the order")
yn("promoGate", "Y: the version must have succeeded in the previous environment")
s("deployUser", 8, "Deploy userid, from DEPLUSER; empty = can't deploy yet")
yn("approvalReq", "Y: deployments need approval")
s("approverGroup", 8, "RACF group of approvers, from RACFGRP")
i("approvalCount", "Number of approvals needed; 0 = none")
i("approvedCount", "Approvals so far")
s("deployerGroup", 8, "RACF group that may deploy; empty = every member")
s("execNode", 8, "JES2 node the jobs run on (/*XEQ); empty = the local node")
yn("envState", "N never deployed, O ok, H possibly half deployed")
i("activeDeplID", "Deployment running or failed here; 0 = none")
i("currentDeplID", "Last succeeded deployment; 0 = none")
i("currentVersionID", "Version last deployed successfully; 0 = none")
s("currentVersionName", 30, "Its name")
ts("deployedDate", "When it was deployed")

i("versionID", "Version key; 0 = none")
s("versionName", 30, "Name, upper case A-Z 0-9 . _ -; ${LWDVER} in JCL")
yn("locType", "D dataset prefix, U USS path")
s("location", 255, "Dataset prefix or USS path; ${LWDLOC} in JCL")
s("versionDescription", 1000, "Description, for example the commit")
yn("versionStatus", "A active, R retired")
yn("isUsed", "Y: requested for deployment at least once; can't be changed")

i("varID", "Variable key")
s("varName", 16, "Name, A-Z 0-9 _, starting with a letter; not starting with LWD")
s("varValue", 255, "Value; never secret")
s("varDescription", 255, "What it is for")

i("templateID", "Template key")
s("templateName", 60, "Name")
i("maxRC", "Highest acceptable return code")
i("currentRev", "Revision used by new deployments; 0 = no JCL yet")
yn("templateStatus", "A active, D deleted")
i("revision", "Template revision; 0 = current")
s("changeNote", 255, "Why it was changed")
i("lineCount", "Number of lines")
i("warningCount", "Warnings found; the first is in infoMessage")
s("jcl", 32400, "JCL: UTF-8 text, lines of at most 80 characters separated by LF, "
  "at most 300 lines, base64 encoded", contentEncoding="base64",
  contentMediaType="text/plain")

i("deplID", "Deployment key")
yn("deplStatus", "W awaiting approval, J rejected, E expired, Q queued, U running, "
   "F failed, S succeeded, C cancelled")
ts("startAfter", "Requested start; empty in a request = now")
s("requestNote", 255, "Why, from the requester")
ts("startedDate", "First job submitted")
ts("endedDate", "Ended")
s("requestedBy", 8, "Requester")
ts("requestedDate", "Requested")
s("commentText", 255, "Comment or reason")

i("jobNo", "Job number in the deployment, 1, 2, ...")
s("jobTitle", 60, "Template name at the time of the request")
i("templateRev", "Template revision that was frozen")
yn("jobStatus", "W waiting, S submitted, D done, F failed, K skipped")
i("lastRunID", "Latest run; 0 = none")
s("skipReason", 255, "Why the job was skipped")

i("runID", "Run key")
s("jobName", 8, "Job name")
yn("runStatus", "N new, S submitted, E ended, F failed")
yn("jobResult", "O within the highest RC, H above it, A abend, X submit failed, "
   "T no result in time; empty = not ended")
s("jesJobID", 8, "JES job ID")
ts("submittedDate", "Submitted")
i("jobRC", "Highest return code; -1 = not known")
s("abendCode", 5, "Abend code, for example S0C4 or U0100")
s("jobMessage", 72, "Message, for example why the submit failed")
yn("outputStatus", "W waiting, C collected, N none found, P purged")
i("nextRunID", "Run of the next job, handed to the CICS submit task; 0 = none")

i("stepNo", "Step number")
s("stepName", 8, "Step")
s("procStep", 8, "Procedure step")
s("pgmName", 8, "Program")
i("stepRC", "Return code; -1 = not known or not executed")
yn("flushed", "Y: not executed")

i("fileNo", "Spool file number")
s("ddName", 8, "DD name")
yn("truncated", "Y: cut off at the OUTLINES setting")
i("lineNum", "Line number")
i("firstLineNum", "Number of the first line in this part")
yn("moreLines", "Y: there are more lines after this part")
s("spoolText", 32000, "At most 300 whole lines of output: UTF-8 text, separated by LF, "
  "base64 encoded",
  contentEncoding="base64", contentMediaType="text/plain")

i("eventNo", "Event number")
yn("eventType", "R requested, A approved, J rejected, Q queued, U started, T retried, "
   "K continued, C cancelled, E expired, S succeeded, F failed")
yn("decision", "A approve, R reject")

i("expiredCount", "Deployments that waited too long for approval and expired")
i("stuckCount", "Runs without a result in time, now failed")
i("mailsSent", "Notification mails sent in this tick")
i("startedDeplID", "Deployment started by this tick; 0 = none")
yn("moreDue", "Y: more queued deployments can start: call again")

s("tableID", 8, "List: RACFGRP, DEPLUSER or SETTINGS")
s("tabKey", 8, "Key in the list")
s("tabValue", 255, "Value or description")

s("createdBy", 8, "RACF userid")
ts("createdDate", "Set by DB2")
s("updatedBy", 8, "RACF userid")
ts("updatedDate", "Set by DB2")

AUDIT = ["createdBy", "createdDate", "updatedBy", "updatedDate"]

# ---------------------------------------------------------------- objects
ME = ["userID", "email", "notifyApprove", "notifyOwn", "notifyApp",
      "isAdmin", "approvalsWaiting"]
ME_REQ = ["notifyApprove", "notifyOwn", "notifyApp"]
APP_LI = ["appID", "appCode", "appName", "isMember", "isOwner", "isApprover"]
APP = ["appID", "appCode", "appName", "appDescription", "accessGroup", "ownerGroup",
       "isMember", "isOwner", "isApprover"] + AUDIT
ADM_APP_LI = ["appID", "appCode", "appName", "accessGroup", "ownerGroup"]
ADM_APP = ["appID", "appCode", "appName", "appDescription", "accessGroup",
           "ownerGroup"] + AUDIT
ADM_APP_REQ = ["appCode", "appName", "appDescription", "accessGroup", "ownerGroup"]
ENV_LI = ["envID", "envCode", "envName", "sortOrder", "promoGate", "approvalReq",
          "approvalCount", "envState", "currentVersionID", "currentVersionName",
          "currentDeplID", "deployedDate", "activeDeplID", "canDeploy", "canApprove"]
ENV = ["envID", "appID", "envCode", "envName", "envDescription", "sortOrder",
       "promoGate", "deployUser", "approvalReq", "approverGroup", "approvalCount",
       "deployerGroup", "execNode", "envState", "currentVersionID", "currentVersionName",
       "currentDeplID", "deployedDate", "activeDeplID", "canDeploy",
       "canApprove"] + AUDIT
ENV_NEW = ["appID", "envCode", "envName", "envDescription", "sortOrder", "promoGate"]
ENV_UPD = ENV_NEW[1:]
ENV_CTL = ["deployUser", "approvalReq", "approverGroup", "approvalCount",
           "deployerGroup", "execNode"]
VER_LI = ["versionID", "versionName", "locType", "location", "versionStatus",
          "isUsed", "createdBy", "createdDate"]
VER = ["versionID", "appID", "versionName", "locType", "location",
       "versionDescription", "versionStatus", "isUsed"] + AUDIT
VER_NEW = ["appID", "versionName", "locType", "location", "versionDescription"]
VER_UPD = VER_NEW[1:]
VAR = ["varID", "appID", "envID", "versionID", "varName", "varValue",
       "varDescription"] + AUDIT
VAR_NEW = ["appID", "envID", "versionID", "varName", "varValue", "varDescription"]
VAR_UPD = ["varName", "varValue", "varDescription"]
TPL_LI = ["templateID", "templateName", "sortOrder", "maxRC", "currentRev",
          "updatedBy", "updatedDate"]
TPL = ["templateID", "appID", "templateName", "sortOrder", "maxRC", "currentRev",
       "templateStatus"] + AUDIT
TPL_NEW = ["appID", "templateName", "sortOrder", "maxRC"]
TPL_UPD = TPL_NEW[1:]
REV_LI = ["revision", "changeNote", "lineCount", "createdBy", "createdDate"]
TJCL = ["templateID", "revision", "lineCount", "jcl"]
TJCL_NEW = ["templateID", "revision", "lineCount", "warningCount"]
DEP_LI = ["deplID", "appID", "appCode", "envID", "envCode", "versionID",
          "versionName", "deplStatus", "startAfter", "requestedBy", "requestedDate",
          "endedDate"]
DEP = ["deplID", "appID", "appCode", "appName", "envID", "envCode", "envName",
       "versionID", "versionName", "location", "deplStatus", "startAfter",
       "requestNote", "deployUser", "approverGroup", "approvalCount",
       "approvedCount", "startedDate", "endedDate", "requestedBy", "requestedDate",
       "canCancel", "canRetry", "canApprove"]
DEP_NEW = ["appID", "envID", "versionID", "startAfter", "requestNote"]
DEP_ACT = ["deplID", "deplStatus"]
JOB_LI = ["jobNo", "jobTitle", "templateID", "templateRev", "maxRC", "jobStatus",
          "lineCount", "lastRunID", "runStatus", "jobResult", "jobRC", "abendCode",
          "skipReason"]
DJCL = ["deplID", "jobNo", "lineCount", "jcl"]
EVT_LI = ["eventNo", "eventType", "jobNo", "commentText", "createdBy",
          "createdDate"]
APR_LI = ["userID", "decision", "commentText", "createdDate"]
APR_NEW = ["deplID", "decision", "commentText"]
APR_RES = ["deplID", "deplStatus", "approvedCount", "approvalCount"]
APQ_LI = ["deplID", "appID", "appCode", "appName", "envID", "envCode", "envName",
          "versionName", "approvedCount", "approvalCount", "startAfter",
          "requestedBy", "requestedDate"]
RUN_LI = ["runID", "jobNo", "jobName", "runStatus", "jobResult", "jesJobID",
          "submittedDate", "endedDate", "jobRC", "abendCode", "jobMessage",
          "outputStatus"]
STP_LI = ["stepNo", "stepName", "procStep", "pgmName", "stepRC", "abendCode",
          "flushed"]
SPF_LI = ["fileNo", "ddName", "stepName", "procStep", "lineCount", "truncated"]
SPT = ["runID", "fileNo", "firstLineNum", "lineCount", "moreLines", "spoolText"]
TICK = ["expiredCount", "stuckCount", "startedDeplID", "moreDue", "mailsSent"]
RES_NEW = ["runID", "jobName", "jesJobID", "jobResult"]
RES = ["runID", "runStatus", "deplStatus", "nextRunID"]
REF = ["tableID", "tabKey", "tabValue"] + AUDIT
REF_NEW = ["tableID", "tabKey", "tabValue"]
REF_UPD = ["tabValue"]
COMMENT = ["commentText"]
STUCK = ["runID", "runStatus", "jobResult", "deplID", "deplStatus"]

# ---------------------------------------------------------------- operations
# (method, path, operationId, summary, tag, use cases, role,
#  params [(name, in, required, schema, description)], request, response, status)
# request: None, list of fields, or ("multipart", fields)
# response: None (ShortResponse), ("obj", fields), ("list", arrayName, fields)
OPS = []


def op(m, p, oid, summ, tag, uc, role, params=(), req=None, res=None, st=None):
    OPS.append(dict(m=m, p=p, oid=oid, summ=summ, tag=tag, uc=uc, role=role,
                    params=list(params), req=req, res=res, st=st))


def pid(name):
    return (name, "path", True, name, name)


def q(name, desc=None, req=True, schema=None):
    return (name, "query", req, schema or name, desc or name)


def since(name):
    return (name + "_since", "query", False, name, "Paging: continue after this value")


def filt(name):
    return (name + "_filter", "query", False, name, "Filter")


U, A, SCH, JOB = "user", "admin", "scheduler", "job"

op("post", "/token", "newAccessToken", "Sign in with RACF userid and passphrase", "public",
   "U1, O4 (CI)", "Anyone", req="TOKEN", res="TOKEN")
op("get", "/me", "getCurrentUser", "Get the signed-in user", U, "U1", "Anyone",
   res=("obj", ME))
op("put", "/me", "updateCurrentUser", "Update own notification settings", U,
   "U2", "Anyone", req=ME_REQ, res=("obj", ME))

op("get", "/applications", "listApplications", "List my applications", U, "M1",
   "Member, owner, approver", [since("appID")], res=("list", "applications", APP_LI))
op("get", "/applications/{appID}", "getApplication", "Get an application", U, "M1",
   "Member, owner, approver", [pid("appID")], res=("obj", APP))

op("get", "/environments", "listEnvironments",
   "List the environments of an application, in order, with the inventory", U,
   "M1, M2, O1", "Member, owner, approver", [q("appID")],
   res=("list", "environments", ENV_LI))
op("get", "/environments/{envID}", "getEnvironment", "Get an environment", U,
   "M2, O1", "Member, owner, approver", [pid("envID")], res=("obj", ENV))
op("post", "/environments", "newEnvironment", "Add an environment", U, "O1", "Owner",
   req=ENV_NEW, res=("obj", ENV))
op("put", "/environments/{envID}", "updateEnvironment",
   "Update name, order and promotion gate", U, "O1", "Owner", [pid("envID")],
   req=ENV_UPD, res=("obj", ENV))
op("delete", "/environments/{envID}", "deleteEnvironment",
   "Delete an environment without deployments", U, "O1", "Owner", [pid("envID")])

op("get", "/versions", "listVersions", "List versions, newest first", U, "M2, D1, O4",
   "Member, owner, approver",
   [q("appID"), filt("versionStatus"), since("versionID")],
   res=("list", "versions", VER_LI))
op("get", "/versions/{versionID}", "getVersion", "Get a version", U, "M2, O4",
   "Member, owner, approver", [pid("versionID")], res=("obj", VER))
op("post", "/versions", "newVersion", "Register a version", U, "O4", "Owner, CI",
   req=VER_NEW, res=("obj", VER))
op("put", "/versions/{versionID}", "updateVersion", "Update a version never used", U,
   "O4", "Owner", [pid("versionID")], req=VER_UPD, res=("obj", VER))
op("delete", "/versions/{versionID}", "deleteVersion", "Delete a version never used",
   U, "O4", "Owner", [pid("versionID")])
op("post", "/versionRetirements/{versionID}", "retireVersion", "Retire a version", U,
   "O4", "Owner", [pid("versionID")], res=("obj", VER), st="200")

op("get", "/variables", "listVariables",
   "List the variables of one level: application, environment or version", U,
   "O1, O3, O4", "Member, owner, approver",
   [q("appID"), q("envID", "Environment; 0 = not this level", False),
    q("versionID", "Version; 0 = not this level", False), since("varID")],
   res=("list", "variables", VAR))
op("post", "/variables", "newVariable", "Add a variable", U, "O1, O3, O4", "Owner",
   req=VAR_NEW, res=("obj", VAR))
op("put", "/variables/{varID}", "updateVariable", "Update a variable", U,
   "O1, O3, O4", "Owner", [pid("varID")], req=VAR_UPD, res=("obj", VAR))
op("delete", "/variables/{varID}", "deleteVariable", "Delete a variable", U,
   "O1, O3, O4", "Owner", [pid("varID")])

op("get", "/templates", "listTemplates", "List the job templates, in order", U,
   "O2", "Member, owner, approver", [q("appID")], res=("list", "templates", TPL_LI))
op("get", "/templates/{templateID}", "getTemplate", "Get a job template", U, "O2",
   "Member, owner, approver", [pid("templateID")], res=("obj", TPL))
op("post", "/templates", "newTemplate", "Add a job template, still without JCL", U,
   "O2", "Owner", req=TPL_NEW, res=("obj", TPL))
op("put", "/templates/{templateID}", "updateTemplate",
   "Update name, order and highest RC", U, "O2", "Owner", [pid("templateID")],
   req=TPL_UPD, res=("obj", TPL))
op("delete", "/templates/{templateID}", "deleteTemplate",
   "Delete a job template; its history stays", U, "O2", "Owner", [pid("templateID")])
op("get", "/templateRevisions", "listTemplateRevisions",
   "List the revisions of a template, newest first", U, "O2",
   "Member, owner, approver", [q("templateID"), since("revision")],
   res=("list", "revisions", REV_LI))
op("get", "/templateJcl/{templateID}", "getTemplateJcl",
   "Get the JCL of a template revision", U, "O2", "Member, owner, approver",
   [pid("templateID"), q("revision", "Revision; 0 = current", False)],
   res=("obj", TJCL))
op("post", "/templateJcl/{templateID}", "newTemplateJcl",
   "Save new JCL as the next revision", U, "O2", "Owner", [pid("templateID")],
   req=("multipart", ["jcl", "changeNote"]), res=("obj", TJCL_NEW))

op("get", "/deployments", "listDeployments", "List deployments, newest first", U,
   "M3", "Member, owner, approver",
   [q("appID", "Application; 0 only with requestedBy_filter = own userid: own requests in every application", False), filt("envID"),
    filt("versionID"), filt("deplStatus"), filt("requestedBy"), filt("deplID"),
    q("appCode_filter", "Filter: application code contains this", False, "appCode"),
    q("envCode_filter", "Filter: environment code contains this", False, "envCode"),
    q("versionName_filter", "Filter: version name contains this", False, "versionName"),
    since("deplID")],
   res=("list", "deployments", DEP_LI))
op("get", "/deployments/{deplID}", "getDeployment", "Get a deployment", U,
   "M3, D2, AP2", "Member, owner, approver", [pid("deplID")], res=("obj", DEP))
op("post", "/deployments", "newDeployment", "Request a deployment", U, "D1",
   "Deployer", req=DEP_NEW, res=("obj", DEP))
op("post", "/cancellations/{deplID}", "cancelDeployment", "Cancel a deployment", U,
   "D3", "Requester, deployer", [pid("deplID")], req=COMMENT, res=("obj", DEP_ACT),
   st="200")
op("post", "/retries/{deplID}", "retryDeployment",
   "Submit the failed job of a deployment again", U, "D4", "Deployer",
   [pid("deplID")], req=COMMENT, res=("obj", DEP_ACT), st="200")
op("post", "/continuations/{deplID}", "continueDeployment",
   "Skip the failed job, with a reason, and go on with the next", U, "D4",
   "Deployer", [pid("deplID")], req=COMMENT, res=("obj", DEP_ACT), st="200")
op("get", "/deploymentJobs", "listDeploymentJobs",
   "List the jobs of a deployment with their latest run", U, "M3, D2",
   "Member, owner, approver", [q("deplID")], res=("list", "jobs", JOB_LI))
op("get", "/deploymentJcl/{deplID}", "getDeploymentJcl",
   "Get the frozen JCL of a job of a deployment", U, "M3, AP2",
   "Member, owner, approver", [pid("deplID"), q("jobNo")], res=("obj", DJCL))
op("get", "/deploymentEvents", "listDeploymentEvents",
   "List the history of a deployment", U, "M3", "Member, owner, approver",
   [q("deplID"), since("eventNo")], res=("list", "events", EVT_LI))

op("get", "/approvalRequests", "listApprovalRequests",
   "List the deployments waiting for my approval, oldest first", U, "AP1",
   "Approver", [since("deplID")], res=("list", "approvalRequests", APQ_LI))
op("get", "/approvals", "listApprovals", "List the decisions on a deployment", U,
   "M3, AP2", "Member, owner, approver", [q("deplID")],
   res=("list", "approvals", APR_LI))
op("post", "/approvals", "newApproval", "Approve or reject a deployment", U, "AP2",
   "Approver", req=APR_NEW, res=("obj", APR_RES))

op("get", "/jobRuns", "listJobRuns", "List the runs of a job of a deployment", U,
   "M3", "Member, owner, approver", [q("deplID"), q("jobNo")],
   res=("list", "runs", RUN_LI))
op("get", "/jobSteps", "listJobSteps", "List the steps of a run", U, "M3",
   "Member, owner, approver", [q("runID"), since("stepNo")],
   res=("list", "steps", STP_LI))
op("get", "/spoolFiles", "listSpoolFiles", "List the collected spool files of a run",
   U, "M4", "Member, owner, approver", [q("runID"), since("fileNo")],
   res=("list", "spoolFiles", SPF_LI))
op("get", "/spoolText/{runID}", "getSpoolText", "Get a part of a spool file", U,
   "M4", "Member, owner, approver", [pid("runID"), q("fileNo"), since("lineNum")],
   res=("obj", SPT))

op("post", "/schedulerTicks", "newSchedulerTick",
   "One tick of the scheduler: expire, mark stuck runs, start one due deployment",
   SCH, "S4", "Scheduler", res=("obj", TICK), st="200")
op("post", "/jobResults", "newJobResult",
   "The result of a run, from the result step of its job; the next job is submitted",
   JOB, "S2", "Deploy userid", req=RES_NEW, res=("obj", RES), st="200")

op("get", "/admin/applications", "adminListApplications", "List all applications",
   A, "A1, A4", "Admin", [since("appID")], res=("list", "applications", ADM_APP_LI))
op("post", "/admin/applications", "adminNewApplication", "Create an application", A,
   "A1", "Admin", req=ADM_APP_REQ, res=("obj", ADM_APP))
op("get", "/admin/applications/{appID}", "adminGetApplication",
   "Get an application", A, "A1", "Admin", [pid("appID")], res=("obj", ADM_APP))
op("put", "/admin/applications/{appID}", "adminUpdateApplication",
   "Update an application", A, "A1", "Admin", [pid("appID")], req=ADM_APP_REQ,
   res=("obj", ADM_APP))
op("delete", "/admin/applications/{appID}", "adminDeleteApplication",
   "Delete an application without deployments", A, "A1", "Admin", [pid("appID")])
op("put", "/admin/environmentControls/{envID}", "adminUpdateEnvironmentControls",
   "Set deploy userid, approval and deployer group", A, "A2", "Admin",
   [pid("envID")], req=ENV_CTL, res=("obj", ENV))
op("get", "/admin/deployments", "adminListDeployments",
   "List deployments of all applications, newest first", A, "A4", "Admin",
   [filt("appID"), filt("deplStatus"), filt("requestedBy"), since("deplID")],
   res=("list", "deployments", DEP_LI))
op("post", "/admin/stuckRuns/{runID}", "adminMarkRunStuck",
   "Mark a submitted run stuck: it fails, with its job and deployment", A, "A4",
   "Admin", [pid("runID")], res=("obj", STUCK), st="200")
op("get", "/admin/refTables", "adminListRefTables",
   "List allowed RACF groups, deploy userids or settings", A, "A3, A5", "Admin",
   [q("tableID"), since("tabKey")], res=("list", "refTables", REF))
op("post", "/admin/refTables", "adminNewRefTable", "Create a reference entry", A,
   "A3", "Admin", req=REF_NEW, res=("obj", REF))
op("put", "/admin/refTables/{tableID}", "adminUpdateRefTable",
   "Update a reference entry", A, "A3, A5", "Admin",
   [pid("tableID"), q("tabKey")], req=REF_UPD, res=("obj", REF))
op("delete", "/admin/refTables/{tableID}", "adminDeleteRefTable",
   "Delete a reference entry not in use", A, "A3", "Admin",
   [pid("tableID"), q("tabKey")])


# ---------------------------------------------------------------- build
def ref(name):
    return {"$ref": "#/components/schemas/" + name}


def short(desc):
    return {"description": desc, "content": {"application/json": {"schema":
            ref("ShortResponse")}}}


def schema_name(o, kind):
    oid = o["oid"]
    base = oid[0].upper() + oid[1:]
    if base.startswith("Admin"):
        return base + kind
    return base + kind


SCHEMAS = {}


def props(fields):
    for f in fields:
        assert f in F, f
    return {f: ref(f) for f in fields}


ENVELOPE = ["retCode", "reasonCode", "infoMessage"]
SCHEMAS["ShortResponse"] = {"type": "object", "properties": props(ENVELOPE)}
SCHEMAS["NewAccessTokenRequest"] = {"type": "object",
                                    "properties": props(["username", "password"])}
SCHEMAS["TokenResponse"] = {"type": "object", "properties": props(["token"])}

paths = {}
for o in OPS:
    p = o["p"]
    if p not in paths:
        seg = p.strip("/").split("/")
        summ = ("Admin: " + seg[1]) if seg[0] == "admin" else seg[0]
        paths[p] = {"summary": summ}
    d = {"summary": o["summ"], "operationId": o["oid"], "tags": [o["tag"]]}
    if o["p"] == "/token":
        d["security"] = []
    if o["params"]:
        d["parameters"] = [{"name": n, "in": w, "description": desc, "required": r,
                            "schema": ref(sch)} for n, w, r, sch, desc in o["params"]]
    req = o["req"]
    if req == "TOKEN":
        d["requestBody"] = {"required": True, "content": {"application/json": {
            "schema": ref("NewAccessTokenRequest")}}}
    elif isinstance(req, tuple):
        nm = schema_name(o, "Request")
        SCHEMAS[nm] = {"type": "object", "required": req[1][:1],
                       "properties": props(req[1])}
        d["requestBody"] = {"required": True, "content": {"multipart/form-data": {
            "schema": ref(nm)}}}
    elif req:
        nm = schema_name(o, "Request")
        SCHEMAS[nm] = {"type": "object", "properties": props(req)}
        d["requestBody"] = {"required": True, "content": {"application/json": {
            "schema": ref(nm)}}}
    res = o["res"]
    if res == "TOKEN":
        rs = "TokenResponse"
    elif res is None:
        rs = "ShortResponse"
    else:
        rs = schema_name(o, "Response")
        pr = props(ENVELOPE)
        if res[0] == "obj":
            pr.update(props(res[1]))
        else:
            pr[res[1]] = {"type": "array", "maxItems": 20,
                          "items": {"type": "object", "properties": props(res[2])}}
        SCHEMAS[rs] = {"type": "object", "properties": pr}
    ok = o["st"] or ("201" if o["m"] == "post" else "200")
    r = {ok: {"description": "Successful", "content": {"application/json": {
        "schema": ref(rs)}}}}
    if o["p"] == "/token":
        r.update({"400": short("Bad request"), "401": {"description": "Unauthorized"},
                  "403": {"description": "Forbidden"}, "404": short("Not found"),
                  "500": short("Internal server error")})
    elif o["oid"] == "getCurrentUser":
        r.update({"401": {"description": "Unauthorized"}, "403": short("Forbidden"),
                  "500": short("Internal server error")})
    else:
        r.update({"400": short("Bad request"), "401": {"description": "Unauthorized"},
                  "403": short("Forbidden"), "404": short("Not found")})
        if o["m"] != "get":
            r["409"] = short("Conflict: duplicate, in use, or not possible in this "
                             "state")
        r["500"] = short("Internal server error")
    r["default"] = {"description": "Unexpected error"}
    d["responses"] = r
    esc = p.replace("/", "~1")
    if o["oid"] in BUILT or o["p"] == "/token":
        d["x-LWWProcessingSteps"] = {
            "$ref": f"lwd_2_1.0.0.yaml/paths/{esc}/{o['m']}/x-LWWProcessingSteps"}
    paths[p][o["m"]] = d

doc = {
    "openapi": "3.2.0",
    "info": {"version": "1.0.0", "title": "LWD API", "description":
             "LWD: deployments of z/OS applications, with approval and RACF access per "
             "application.\nTags give the access level: user (any signed-in user; "
             "COBOL checks the role per application and environment), admin, "
             "scheduler, job.\n"},
    "servers": [{"url": "https://<host>:<port>/lwdeploy/API/v1"}],
    "security": [{"bearerAuth": []}],
    "tags": [{"name": "public", "description": "No token: POST /token only"},
             {"name": "user", "description": "Signed-in user; roles checked in COBOL "
              "through FACILITY profiles"},
             {"name": "admin", "description": "Administrator; FACILITY check in COBOL"},
             {"name": "scheduler", "description": "The scheduler's userid only "
              "(setting SCHEDUSR), through its own transaction"},
             {"name": "job", "description": "The deploy userids only, from the result "
              "step of a deployment job, through their own transaction"}],
    "paths": paths,
    "components": {
        "securitySchemes": {"bearerAuth": {
            "type": "http", "scheme": "bearer",
            "description": "Token from POST /token, or from LWW's sign-in (RACF or "
                           "Entra)"}},
        "schemas": dict(sorted(F.items(), key=lambda kv: kv[0].lower())) | SCHEMAS,
    },
}


class D(yaml.SafeDumper):
    # LWW doesn't read YAML anchors and aliases (&id001, *id001)
    def ignore_aliases(self, data):
        return True


def str_rep(dumper, data):
    if "\n" in data:
        return dumper.represent_scalar("tag:yaml.org,2002:str", data, style="|")
    return dumper.represent_scalar("tag:yaml.org,2002:str", data)


D.add_representer(str, str_rep)
with open(OUT_YAML, "w") as f:
    yaml.dump(doc, f, Dumper=D, sort_keys=False, width=100, allow_unicode=True)

# ---------------------------------------------------------------- md tables
SECTIONS = [
    ("Sign-in and profile", ["/token", "/me"]),
    ("Applications and environments", ["/applications", "/environments"]),
    ("Versions and variables", ["/versions", "/versionRetirements", "/variables"]),
    ("Job templates", ["/templates", "/templateRevisions", "/templateJcl"]),
    ("Deployments", ["/deployments", "/cancellations", "/retries", "/continuations",
                     "/deploymentJobs", "/deploymentJcl", "/deploymentEvents"]),
    ("Approvals", ["/approvalRequests", "/approvals"]),
    ("Runs and output", ["/jobRuns", "/jobSteps", "/spoolFiles", "/spoolText"]),
    ("Scheduler and result step", ["/schedulerTicks", "/jobResults"]),
    ("Admin", ["/admin"]),
]
used = set()
md = []
for title, prefixes in SECTIONS:
    md += [f"### {title}", "", "| Method | Path | What it does | Who | Use cases |",
           "|---|---|---|---|---|"]
    for k, o in enumerate(OPS):
        root = "/" + o["p"].strip("/").split("/")[0]
        if root in prefixes and k not in used:
            used.add(k)
            md.append(f"| {o['m'].upper()} | `{o['p']}` | {o['summ']} | {o['role']} | "
                      f"{o['uc']} |")
    md.append("")
assert len(used) == len(OPS)
with open(OUT_MD, "w") as f:
    f.write("\n".join(md))
nu = sum(1 for o in OPS if o["tag"] == U)
na = sum(1 for o in OPS if o["tag"] == A)
print(len(OPS), "operations:", nu, "user,", na, "admin, 1 scheduler, 1 job;",
      len(SCHEMAS) + len(F), "schemas")
