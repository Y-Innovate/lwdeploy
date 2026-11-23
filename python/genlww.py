"""Generate, for the operations built so far, from one table:
- COPY/LLWDMnnn.cpy       the IO area of each module
- openapi/lwd_2_1.0.0.yaml the LWW processing steps and x-ioareas
- COBOL/LWDCnnn.cbl       the CICS wrapper of each module
- LKED/*.lked             link-edit decks of wrappers, modules and routines
Run from the repository root: python python/genlww.py
The public contract comes first: python python/genoas.py. Program numbers:
first digit 2 list, 3 get, 4 create, 5 action, 9 support; then the table.
"""
import os
import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OAS1 = "lwd_1.0.0.yaml"
OAS2 = "lwd_2_1.0.0.yaml"

# ------------------------------------------------------------------ fields
# JSON name: (COBOL name, kind, length). Kinds: N PIC N(n), V varchar of
# PIC N(n), X PIC X(n), I4 S9(9) COMP-5, I2 S9(4) COMP-5.
F = {
    "retCode": ("RETURNCODE", "N", 2), "reasonCode": ("REASONCODE", "N", 2),
    "infoMessage": ("INFOMESSAGE", "N", 72),
    "userID": ("USERID", "N", 8), "email": ("EMAIL", "V", 254),
    "notifyApprove": ("NOTIFYAPPROVE", "N", 1), "notifyOwn": ("NOTIFYOWN", "N", 1),
    "notifyApp": ("NOTIFYAPP", "N", 1), "isAdmin": ("ISADMIN", "N", 1),
    "approvalsWaiting": ("APPROVALSWAITING", "I4", 4),
    "appID": ("APPID", "I4", 4), "appCode": ("APPCODE", "N", 8),
    "appName": ("APPNAME", "V", 60), "isMember": ("ISMEMBER", "N", 1),
    "appDescription": ("APPDESCRIPTION", "V", 1000),
    "accessGroup": ("ACCESSGROUP", "N", 8), "ownerGroup": ("OWNERGROUP", "N", 8),
    "isOwner": ("ISOWNER", "N", 1), "isApprover": ("ISAPPROVER", "N", 1),
    "envID": ("ENVID", "I4", 4), "envCode": ("ENVCODE", "N", 8),
    "envName": ("ENVNAME", "V", 60), "sortOrder": ("SORTORDER", "I2", 2),
    "promoGate": ("PROMOGATE", "N", 1), "approvalReq": ("APPROVALREQ", "N", 1),
    "approvalCount": ("APPROVALCOUNT", "I2", 2),
    "approvedCount": ("APPROVEDCOUNT", "I2", 2), "envState": ("ENVSTATE", "N", 1),
    "currentVersionID": ("CURRENTVERSIONID", "I4", 4),
    "currentVersionName": ("CURRENTVERSIONNAME", "V", 30),
    "currentDeplID": ("CURRENTDEPLID", "I4", 4),
    "deployedDate": ("DEPLOYEDDATE", "N", 26),
    "activeDeplID": ("ACTIVEDEPLID", "I4", 4), "canDeploy": ("CANDEPLOY", "N", 1),
    "canApprove": ("CANAPPROVE", "N", 1), "canCancel": ("CANCANCEL", "N", 1),
    "canRetry": ("CANRETRY", "N", 1),
    "versionID": ("VERSIONID", "I4", 4), "versionName": ("VERSIONNAME", "V", 30),
    "locType": ("LOCTYPE", "N", 1), "location": ("LOCATION", "V", 255),
    "versionDescription": ("DESCRIPTION", "V", 1000),
    "versionStatus": ("VERSIONSTATUS", "N", 1), "isUsed": ("ISUSED", "N", 1),
    "createdBy": ("CREATEDBY", "N", 8), "createdDate": ("CREATEDDATE", "N", 26),
    "updatedBy": ("UPDATEDBY", "N", 8), "updatedDate": ("UPDATEDDATE", "N", 26),
    "deplID": ("DEPLID", "I4", 4), "deplStatus": ("DEPLSTATUS", "N", 1),
    "startAfter": ("STARTAFTER", "N", 26), "requestNote": ("REQUESTNOTE", "V", 255),
    "deployUser": ("DEPLOYUSER", "N", 8), "approverGroup": ("APPROVERGROUP", "N", 8),
    "startedDate": ("STARTEDDATE", "N", 26), "endedDate": ("ENDEDDATE", "N", 26),
    "requestedBy": ("REQUESTEDBY", "N", 8), "requestedDate": ("REQUESTEDDATE", "N", 26),
    "jobNo": ("JOBNO", "I2", 2), "jobTitle": ("JOBTITLE", "V", 60),
    "templateID": ("TEMPLATEID", "I4", 4), "templateRev": ("TEMPLATEREV", "I2", 2),
    "maxRC": ("MAXRC", "I2", 2), "jobStatus": ("JOBSTATUS", "N", 1),
    "lineCount": ("LINECOUNT", "I4", 4), "lastRunID": ("LASTRUNID", "I4", 4),
    "runStatus": ("RUNSTATUS", "N", 1), "jobResult": ("JOBRESULT", "N", 1),
    "jobRC": ("JOBRC", "I2", 2), "abendCode": ("ABENDCODE", "N", 5),
    "skipReason": ("SKIPREASON", "V", 255), "commentText": ("COMMENTTEXT", "V", 255),
    "jcl": ("JCL", "X", 32400),
    "eventNo": ("EVENTNO", "I2", 2), "eventType": ("EVENTTYPE", "N", 1),
    "decision": ("DECISION", "N", 1),
    "runID": ("RUNID", "I4", 4), "jobName": ("JOBNAME", "N", 8),
    "jesJobID": ("JESJOBID", "N", 8), "submittedDate": ("SUBMITTEDDATE", "N", 26),
    "jobMessage": ("JOBMESSAGE", "V", 72), "outputStatus": ("OUTPUTSTATUS", "N", 1),
    "expiredCount": ("EXPIREDCOUNT", "I2", 2), "stuckCount": ("STUCKCOUNT", "I2", 2),
    "mailsSent": ("MAILSSENT", "I2", 2),
    "startedDeplID": ("STARTEDDEPLID", "I4", 4), "moreDue": ("MOREDUE", "N", 1),
    "stepNo": ("STEPNO", "I2", 2), "stepName": ("STEPNAME", "N", 8),
    "procStep": ("PROCSTEP", "N", 8), "pgmName": ("PGMNAME", "N", 8),
    "stepRC": ("STEPRC", "I2", 2), "flushed": ("FLUSHED", "N", 1),
    "fileNo": ("FILENO", "I2", 2), "ddName": ("DDNAME", "N", 8),
    "truncated": ("TRUNCATED", "N", 1),
    "firstLineNum": ("FIRSTLINENUM", "I4", 4),
    "moreLines": ("MORELINES", "N", 1), "spoolText": ("SPOOLTEXT", "X", 32000),
    "nextRunID": ("NEXTRUNID", "I4", 4),
    "execNode": ("EXECNODE", "N", 8), "deployerGroup": ("DEPLOYERGROUP", "N", 8),
    "envDescription": ("ENVDESCRIPTION", "V", 1000),
    "tableID": ("TABLEID", "N", 8), "tabKey": ("TABKEY", "N", 8),
    "tabValue": ("TABVALUE", "V", 255),
    "varID": ("VARID", "I4", 4), "varName": ("VARNAME", "V", 16),
    "varValue": ("VARVALUE", "V", 255), "varDescription": ("VARDESCRIPTION", "V", 255),
    "templateName": ("TEMPLATENAME", "V", 60), "currentRev": ("CURRENTREV", "I2", 2),
    "templateStatus": ("TEMPLATESTATUS", "N", 1), "revision": ("REVISION", "I2", 2),
    "changeNote": ("CHANGENOTE", "V", 255), "warningCount": ("WARNINGCOUNT", "I2", 2),
    # Not in the contract: the length of the form field jcl (LWDC410)
    "jclLength": ("JCLLENGTH", "I4", 4),
    # Not in the contract: set by LWW per path (type constant)
    "deplAction": ("DEPLACTION", "N", 1),
    "opCode": ("OPCODE", "N", 1), "adminView": ("ADMINVIEW", "N", 1),
    # Paging and filters
    "appID_since": ("APPID-SINCE", "I4", 4),
    "versionID_since": ("VERSIONID-SINCE", "I4", 4),
    "versionStatus_filter": ("VERSIONSTATUS-FILTER", "N", 1),
    "deplID_since": ("DEPLID-SINCE", "I4", 4),
    "envID_filter": ("ENVID-FILTER", "I4", 4),
    "versionID_filter": ("VERSIONID-FILTER", "I4", 4),
    "deplStatus_filter": ("DEPLSTATUS-FILTER", "N", 1),
    "requestedBy_filter": ("REQUESTEDBY-FILTER", "N", 8),
    "deplID_filter": ("DEPLID-FILTER", "I4", 4),
    "appCode_filter": ("APPCODE-FILTER", "N", 8),
    "envCode_filter": ("ENVCODE-FILTER", "N", 8),
    "versionName_filter": ("VERSIONNAME-FILTER", "N", 30),
    "eventNo_since": ("EVENTNO-SINCE", "I2", 2),
    "stepNo_since": ("STEPNO-SINCE", "I2", 2),
    "fileNo_since": ("FILENO-SINCE", "I2", 2),
    "lineNum_since": ("LINENUM-SINCE", "I4", 4),
    "tabKey_since": ("TABKEY-SINCE", "N", 8),
    "varID_since": ("VARID-SINCE", "I4", 4),
    "revision_since": ("REVISION-SINCE", "I2", 2),
}

ENVELOPE = ["retCode", "reasonCode", "infoMessage"]
AUDIT = ["createdBy", "createdDate", "updatedBy", "updatedDate"]
ME = ["userID", "email", "notifyApprove", "notifyOwn", "notifyApp", "isAdmin",
      "approvalsWaiting"]
APP_LI = ["appID", "appCode", "appName", "isMember", "isOwner", "isApprover"]
APP = ["appID", "appCode", "appName", "appDescription", "accessGroup", "ownerGroup",
       "isMember", "isOwner", "isApprover"] + AUDIT
# GET /applications and /admin/applications share LWDM204 and its list
ADM_APP_LI = ["appID", "appCode", "appName", "accessGroup", "ownerGroup"]
APP_LI_ALL = APP_LI + ["accessGroup", "ownerGroup"]
ADM_APP = ["appID", "appCode", "appName", "appDescription", "accessGroup",
           "ownerGroup"] + AUDIT
APP_IO = ["appID", "opCode", "appCode", "appName", "appDescription", "accessGroup",
          "ownerGroup"] + AUDIT
APP_BODY = [("appCode", "body", True), ("appName", "body", True),
            ("appDescription", "body", False), ("accessGroup", "body", True),
            ("ownerGroup", "body", True)]
ENV_LI = ["envID", "envCode", "envName", "sortOrder", "promoGate", "approvalReq",
          "approvalCount", "envState", "currentVersionID", "currentVersionName",
          "currentDeplID", "deployedDate", "activeDeplID", "canDeploy", "canApprove"]
# One environment, as LWDM006 answers it for every OPCODE
ENV = ["envID", "appID", "envCode", "envName", "envDescription", "sortOrder",
       "promoGate", "deployUser", "approvalReq", "approverGroup", "approvalCount",
       "deployerGroup", "execNode", "envState", "currentVersionID",
       "currentVersionName", "currentDeplID", "deployedDate", "activeDeplID",
       "canDeploy", "canApprove"] + AUDIT
ENV_IO = ["envID", "opCode"] + ENV[1:]
ENV_CTL = [("deployUser", "body", False), ("approvalReq", "body", True),
           ("approverGroup", "body", False), ("approvalCount", "body", False),
           ("deployerGroup", "body", False), ("execNode", "body", False)]
REF = ["tableID", "tabKey", "tabValue"] + AUDIT
REF_IO = ["tableID", "tabKey", "opCode", "tabValue"] + AUDIT
DEP_IO = ["appID", "envID_filter", "versionID_filter", "deplStatus_filter",
          "requestedBy_filter", "deplID_filter", "appCode_filter",
          "envCode_filter", "versionName_filter", "deplID_since", "adminView"]
STUCK = ["runID", "runStatus", "jobResult", "deplID", "deplStatus"]
ENV_BODY = [("envCode", "body", True), ("envName", "body", True),
            ("envDescription", "body", False), ("sortOrder", "body", False),
            ("promoGate", "body", False)]
VER_IO = ["versionID", "opCode"] + ["appID", "versionName", "locType", "location",
                                    "versionDescription", "versionStatus", "isUsed",
                                    "createdBy", "createdDate", "updatedBy",
                                    "updatedDate"]
VER_BODY = [("versionName", "body", True), ("locType", "body", True),
            ("location", "body", True), ("versionDescription", "body", False)]
VAR = ["varID", "appID", "envID", "versionID", "varName", "varValue",
       "varDescription"] + AUDIT
VAR_IO = ["varID", "opCode"] + VAR[1:]
VAR_BODY = [("varName", "body", True), ("varValue", "body", False),
            ("varDescription", "body", False)]
TPL_LI = ["templateID", "templateName", "sortOrder", "maxRC", "currentRev",
          "updatedBy", "updatedDate"]
TPL = ["templateID", "appID", "templateName", "sortOrder", "maxRC", "currentRev",
       "templateStatus"] + AUDIT
TPL_IO = ["templateID", "opCode"] + TPL[1:]
TPL_BODY = [("templateName", "body", True), ("sortOrder", "body", False),
            ("maxRC", "body", False)]
REV_LI = ["revision", "changeNote", "lineCount", "createdBy", "createdDate"]
TJCL_NEW = ["templateID", "revision", "lineCount", "warningCount"]
VER_LI = ["versionID", "versionName", "locType", "location", "versionStatus",
          "isUsed", "createdBy", "createdDate"]
VER = ["versionID", "appID", "versionName", "locType", "location",
       "versionDescription", "versionStatus", "isUsed"] + AUDIT
DEP = ["deplID", "appID", "appCode", "appName", "envID", "envCode", "envName",
       "versionID", "versionName", "location", "deplStatus", "startAfter",
       "requestNote", "deployUser", "approverGroup", "approvalCount",
       "approvedCount", "startedDate", "endedDate", "requestedBy", "requestedDate",
       "canCancel", "canRetry", "canApprove"]
DEP_LI = ["deplID", "appID", "appCode", "envID", "envCode", "versionID",
          "versionName", "deplStatus", "startAfter", "requestedBy", "requestedDate",
          "endedDate"]
JOB_LI = ["jobNo", "jobTitle", "templateID", "templateRev", "maxRC", "jobStatus",
          "lineCount", "lastRunID", "runStatus", "jobResult", "jobRC", "abendCode",
          "skipReason"]
EVT_LI = ["eventNo", "eventType", "jobNo", "commentText", "createdBy",
          "createdDate"]
APR_LI = ["userID", "decision", "commentText", "createdDate"]
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
RES = ["runID", "runStatus", "deplStatus", "nextRunID"]
DEPL_ACTION = [("deplID", "path", True), ("commentText", "body", False)]

# ------------------------------------------------------------------ operations
# operationId: module number, inputs [(json name, source, required)],
# scalar outputs, list (json array, COBOL prefix, fields) or None,
# HTTP status when OK, and whether the wrapper starts the submit task.
# Sources: query, path, body; a fourth element maps the input onto another
# field (appID_filter onto APPID). Several paths can share one program (nr):
# const sets a field per path (LWW mapping type constant), sfx keeps the
# names of their LWW steps apart, and desc is the wrapper's header line.
# Paths that share a program must share its IO area: io gives its fields in
# order, lst its list with every field any of them needs, lmap the fields of
# the list this path answers. created: (field, value) for which the shared
# wrapper answers 201 instead of 200.
OPS = {
    "getCurrentUser": dict(nr="302", inp=[], out=ME),
    # PUT /me: LWDM002, the module of USERS; OPCODE so it can grow
    "updateCurrentUser": dict(nr="002", inp=[("notifyApprove", "body", True),
                                             ("notifyOwn", "body", True),
                                             ("notifyApp", "body", True)],
                              const=("opCode", "U"), sfx="U", io=["opCode"] + ME,
                              out=ME),
    "listApplications": dict(nr="204", inp=[("appID_since", "query", False)],
                             io=["appID_since", "adminView"], out=[],
                             lst=("applications", "APP", APP_LI_ALL), lmap=APP_LI,
                             desc="GET /applications, /admin/applications."),
    "adminListApplications": dict(nr="204", inp=[("appID_since", "query", False)],
                                  const=("adminView", "Y"), sfx="A",
                                  io=["appID_since", "adminView"], out=[],
                                  lst=("applications", "APP", APP_LI_ALL),
                                  lmap=ADM_APP_LI,
                                  desc="GET /applications, /admin/applications."),
    "adminGetApplication": dict(nr="004", inp=[("appID", "path", True)],
                                const=("opCode", "R"), sfx="R", io=APP_IO,
                                out=ADM_APP, created=("opCode", "C"),
                                desc="GET, POST, PUT, DELETE /admin/applications."),
    "adminNewApplication": dict(nr="004", inp=APP_BODY, const=("opCode", "C"),
                                sfx="C", io=APP_IO, out=ADM_APP, ok=201,
                                created=("opCode", "C"),
                                desc="GET, POST, PUT, DELETE /admin/applications."),
    "adminUpdateApplication": dict(nr="004", inp=[("appID", "path", True)] + APP_BODY,
                                   const=("opCode", "U"), sfx="U", io=APP_IO,
                                   out=ADM_APP, created=("opCode", "C"),
                                   desc="GET, POST, PUT, DELETE "
                                        "/admin/applications."),
    "adminDeleteApplication": dict(nr="004", inp=[("appID", "path", True)],
                                   const=("opCode", "D"), sfx="D", io=APP_IO,
                                   out=[], created=("opCode", "C"),
                                   desc="GET, POST, PUT, DELETE "
                                        "/admin/applications."),
    "getEnvironment": dict(nr="006", inp=[("envID", "path", True)],
                           const=("opCode", "R"), sfx="R", io=ENV_IO, out=ENV,
                           created=("opCode", "C"),
                           desc="/environments, /admin/environmentControls."),
    "adminUpdateEnvironmentControls": dict(nr="006",
                                           inp=[("envID", "path", True)] + ENV_CTL,
                                           const=("opCode", "K"), sfx="K",
                                           io=ENV_IO, out=ENV,
                                           created=("opCode", "C"),
                                           desc="/environments, "
                                                "/admin/environmentControls."),
    "newEnvironment": dict(nr="006", inp=[("appID", "body", True)] + ENV_BODY,
                           const=("opCode", "C"), sfx="C", io=ENV_IO, out=ENV,
                           ok=201, created=("opCode", "C"),
                           desc="/environments, /admin/environmentControls."),
    "updateEnvironment": dict(nr="006", inp=[("envID", "path", True)] + ENV_BODY,
                              const=("opCode", "U"), sfx="U", io=ENV_IO, out=ENV,
                              created=("opCode", "C"),
                              desc="/environments, /admin/environmentControls."),
    "deleteEnvironment": dict(nr="006", inp=[("envID", "path", True)],
                              const=("opCode", "D"), sfx="D", io=ENV_IO, out=[],
                              created=("opCode", "C"),
                              desc="/environments, /admin/environmentControls."),
    "getVersion": dict(nr="005", inp=[("versionID", "path", True)],
                       const=("opCode", "R"), sfx="R", io=VER_IO, out=VER,
                       desc="/versions/{versionID}, /versionRetirements."),
    "updateVersion": dict(nr="005", inp=[("versionID", "path", True)] + VER_BODY,
                          const=("opCode", "U"), sfx="U", io=VER_IO, out=VER,
                          desc="/versions/{versionID}, /versionRetirements."),
    "deleteVersion": dict(nr="005", inp=[("versionID", "path", True)],
                          const=("opCode", "D"), sfx="D", io=VER_IO, out=[],
                          desc="/versions/{versionID}, /versionRetirements."),
    "retireVersion": dict(nr="005", inp=[("versionID", "path", True)],
                          const=("opCode", "T"), sfx="T", io=VER_IO, out=VER,
                          desc="/versions/{versionID}, /versionRetirements."),
    "listVariables": dict(nr="207", inp=[("appID", "query", True),
                                         ("envID", "query", False),
                                         ("versionID", "query", False),
                                         ("varID_since", "query", False)],
                          out=[], lst=("variables", "VAR", VAR)),
    "newVariable": dict(nr="007", inp=[("appID", "body", True), ("envID", "body", False),
                                       ("versionID", "body", False)] + VAR_BODY,
                        const=("opCode", "C"), sfx="C", io=VAR_IO, out=VAR, ok=201,
                        created=("opCode", "C"), desc="POST, PUT, DELETE /variables."),
    "updateVariable": dict(nr="007", inp=[("varID", "path", True)] + VAR_BODY,
                           const=("opCode", "U"), sfx="U", io=VAR_IO, out=VAR,
                           created=("opCode", "C"),
                           desc="POST, PUT, DELETE /variables."),
    "deleteVariable": dict(nr="007", inp=[("varID", "path", True)],
                           const=("opCode", "D"), sfx="D", io=VAR_IO, out=[],
                           created=("opCode", "C"),
                           desc="POST, PUT, DELETE /variables."),
    "listTemplates": dict(nr="208", inp=[("appID", "query", True)], out=[],
                          lst=("templates", "TPL", TPL_LI)),
    "getTemplate": dict(nr="008", inp=[("templateID", "path", True)],
                        const=("opCode", "R"), sfx="R", io=TPL_IO, out=TPL,
                        created=("opCode", "C"), desc="/templates."),
    "newTemplate": dict(nr="008", inp=[("appID", "body", True)] + TPL_BODY,
                        const=("opCode", "C"), sfx="C", io=TPL_IO, out=TPL, ok=201,
                        created=("opCode", "C"), desc="/templates."),
    "updateTemplate": dict(nr="008", inp=[("templateID", "path", True)] + TPL_BODY,
                           const=("opCode", "U"), sfx="U", io=TPL_IO, out=TPL,
                           created=("opCode", "C"), desc="/templates."),
    "deleteTemplate": dict(nr="008", inp=[("templateID", "path", True)],
                           const=("opCode", "D"), sfx="D", io=TPL_IO, out=[],
                           created=("opCode", "C"), desc="/templates."),
    "listTemplateRevisions": dict(nr="209", inp=[("templateID", "query", True),
                                                 ("revision_since", "query", False)],
                                  out=[], lst=("revisions", "REV", REV_LI)),
    "getTemplateJcl": dict(nr="310", inp=[("templateID", "path", True),
                                          ("revision", "query", False)],
                           out=["templateID", "revision", "lineCount", "jcl"]),
    # LWW passes only the ID; local wrapper LWDW410 reads the form fields
    "newTemplateJcl": dict(nr="410", inp=[("templateID", "path", True)],
                           io=["templateID", "jclLength", "jcl", "changeNote",
                               "revision", "lineCount", "warningCount"],
                           out=TJCL_NEW, ok=201, form=True),
    "adminListRefTables": dict(nr="201", inp=[("tableID", "query", True),
                                              ("tabKey_since", "query", False)],
                               out=[], lst=("refTables", "REF", REF)),
    "adminNewRefTable": dict(nr="001", inp=[("tableID", "body", True),
                                            ("tabKey", "body", True),
                                            ("tabValue", "body", False)],
                             const=("opCode", "C"), sfx="C", io=REF_IO, out=REF,
                             ok=201, created=("opCode", "C"),
                             desc="POST, PUT, DELETE /admin/refTables."),
    "adminUpdateRefTable": dict(nr="001", inp=[("tableID", "path", True),
                                               ("tabKey", "query", True),
                                               ("tabValue", "body", False)],
                                const=("opCode", "U"), sfx="U", io=REF_IO,
                                out=REF, created=("opCode", "C"),
                                desc="POST, PUT, DELETE /admin/refTables."),
    "adminDeleteRefTable": dict(nr="001", inp=[("tableID", "path", True),
                                               ("tabKey", "query", True)],
                                const=("opCode", "D"), sfx="D", io=REF_IO,
                                out=[], created=("opCode", "C"),
                                desc="POST, PUT, DELETE /admin/refTables."),
    "adminMarkRunStuck": dict(nr="514", inp=[("runID", "path", True)], out=STUCK),
    "getApplication": dict(nr="304", inp=[("appID", "path", True)], out=APP),
    "listEnvironments": dict(nr="206", inp=[("appID", "query", True)], out=[],
                             lst=("environments", "ENV", ENV_LI)),
    "listVersions": dict(nr="205", inp=[("appID", "query", True),
                                        ("versionStatus_filter", "query", False),
                                        ("versionID_since", "query", False)],
                         out=[], lst=("versions", "VER", VER_LI)),
    "newVersion": dict(nr="405", inp=[("appID", "body", True),
                                      ("versionName", "body", True),
                                      ("locType", "body", True),
                                      ("location", "body", True),
                                      ("versionDescription", "body", False)],
                       out=VER, ok=201),
    "newDeployment": dict(nr="411", inp=[("appID", "body", True),
                                         ("envID", "body", True),
                                         ("versionID", "body", True),
                                         ("startAfter", "body", False),
                                         ("requestNote", "body", False)],
                          out=DEP, ok=201, submit=True),
    "listDeployments": dict(nr="211", inp=[("appID", "query", False),
                                           ("envID_filter", "query", False),
                                           ("versionID_filter", "query", False),
                                           ("deplStatus_filter", "query", False),
                                           ("requestedBy_filter", "query", False),
                                           ("deplID_filter", "query", False),
                                           ("appCode_filter", "query", False),
                                           ("envCode_filter", "query", False),
                                           ("versionName_filter", "query", False),
                                           ("deplID_since", "query", False)],
                            io=DEP_IO, out=[], lst=("deployments", "DEP", DEP_LI),
                            desc="GET /deployments, /admin/deployments."),
    "adminListDeployments": dict(nr="211",
                                 inp=[("appID_filter", "query", False, "appID"),
                                      ("deplStatus_filter", "query", False),
                                      ("requestedBy_filter", "query", False),
                                      ("deplID_since", "query", False)],
                                 const=("adminView", "Y"), sfx="A", io=DEP_IO,
                                 out=[], lst=("deployments", "DEP", DEP_LI),
                                 desc="GET /deployments, /admin/deployments."),
    "getDeployment": dict(nr="311", inp=[("deplID", "path", True)], out=DEP),
    "cancelDeployment": dict(nr="511", inp=DEPL_ACTION, const=("deplAction", "C"),
                             sfx="C", out=["deplID", "deplStatus"], submit=True,
                             desc="POST /cancellations, /retries, /continuations."),
    "retryDeployment": dict(nr="511", inp=DEPL_ACTION, const=("deplAction", "T"),
                            sfx="T", out=["deplID", "deplStatus"], submit=True,
                            desc="POST /cancellations, /retries, /continuations."),
    "continueDeployment": dict(nr="511", inp=DEPL_ACTION,
                               const=("deplAction", "K"), sfx="K",
                               out=["deplID", "deplStatus"], submit=True,
                               desc="POST /cancellations, /retries, "
                                    "/continuations."),
    "listDeploymentJobs": dict(nr="212", inp=[("deplID", "query", True)], out=[],
                               lst=("jobs", "JOB", JOB_LI)),
    "getDeploymentJcl": dict(nr="313", inp=[("deplID", "path", True),
                                            ("jobNo", "query", True)],
                             out=["deplID", "jobNo", "lineCount", "jcl"]),
    "listDeploymentEvents": dict(nr="219", inp=[("deplID", "query", True),
                                                ("eventNo_since", "query", False)],
                                 out=[], lst=("events", "EVT", EVT_LI)),
    "listApprovalRequests": dict(nr="290", inp=[("deplID_since", "query", False)],
                                 out=[], lst=("approvalRequests", "APQ", APQ_LI)),
    "listApprovals": dict(nr="218", inp=[("deplID", "query", True)], out=[],
                          lst=("approvals", "APR", APR_LI)),
    "newApproval": dict(nr="418", inp=[("deplID", "body", True),
                                       ("decision", "body", True),
                                       ("commentText", "body", False)],
                        out=["deplID", "deplStatus", "approvedCount",
                             "approvalCount"], ok=201, submit=True),
    "listJobRuns": dict(nr="214", inp=[("deplID", "query", True),
                                       ("jobNo", "query", True)],
                        out=[], lst=("runs", "RUN", RUN_LI)),
    "listJobSteps": dict(nr="215", inp=[("runID", "query", True),
                                        ("stepNo_since", "query", False)],
                         out=[], lst=("steps", "STP", STP_LI)),
    "listSpoolFiles": dict(nr="216", inp=[("runID", "query", True),
                                          ("fileNo_since", "query", False)],
                           out=[], lst=("spoolFiles", "SPF", SPF_LI)),
    "getSpoolText": dict(nr="317", inp=[("runID", "path", True),
                                        ("fileNo", "query", True),
                                        ("lineNum_since", "query", False)],
                         out=SPT),
    # After the commit its wrapper sends the queued mails (LWDC950)
    "newSchedulerTick": dict(nr="930", inp=[], out=TICK, submit=True, mail=True),
    "newJobResult": dict(nr="916", inp=[("runID", "body", True),
                                        ("jobName", "body", True),
                                        ("jesJobID", "body", False),
                                        ("jobResult", "body", True)],
                         out=RES, submit=True),
}

# Support programs that only need a link-edit deck: name -> extra includes
SUPPORT = {"LWDA990": [], "LWDA991": [], "LWDA992": [], "LWDU981": [],
           "LWDC910": [], "LWDM910": ["DSNCLI"],
           "LWDC950": [], "LWDM950": ["DSNCLI"], "LWDM960": ["DSNELI"],
           "LWDM920": ["DSNCLI"], "LWDM915": ["LWDM920", "DSNELI"],
           "LWDM940": ["DSNELI"], "LWDM945": ["DSNELI"]}


def kind_size(k, n):
    return {"N": 2 * n, "V": 2 + 2 * n, "X": n, "I4": 4, "I2": 2}[k]


def cobol_line(level, name, k, n, ind):
    pad = " " * ind
    if k == "V":
        return [f"{pad}{level} {name}.",
                f"{pad}   49 {name}-LEN PIC S9(4) USAGE COMP-5.",
                f"{pad}   49 {name}-TEXT PIC N({n})."]
    pic = {"N": f"PIC N({n:02d}).", "X": f"PIC X({n}).",
           "I4": "PIC S9(9) USAGE COMP-5.", "I2": "PIC S9(4) USAGE COMP-5."}[k]
    if k == "N" and n == 1:
        pic = "PIC N."
    return [f"{pad}{level} {name.ljust(19)} {pic}"]


def ioarea_field(name, k, n):
    t = {"N": "CHARARRAY1200", "V": "VARCHAR1200", "X": "CHARARRAY037",
         "I4": "UI4", "I2": "UI2"}[k]
    return {"name": name, "type": t, "length": n}


def target(i):
    """The field an input goes to: its own, or the fourth element"""
    return i[3] if len(i) > 3 else i[0]


def layout(oid, o):
    """Ordered scalar fields (json names) and the list, without duplicates."""
    scal = []
    const = [o["const"][0]] if o.get("const") else []
    if o.get("io"):
        scal = ENVELOPE + o["io"]
        for f in [target(i) for i in o["inp"]] + const + o["out"]:
            assert f in scal, (oid, f)
        return scal, o.get("lst")
    for f in ENVELOPE + [target(i) for i in o["inp"]] + const + o["out"]:
        if f not in scal:
            scal.append(f)
    return scal, o.get("lst")


def item_name(o, f):
    """COBOL name of list field f: prefixed with the list's prefix when a
    field outside the list has the same name, so no reference is ambiguous."""
    scal, lst = layout(None, o)
    name = F[f][0]
    if name in {F[x][0] for x in scal}:
        return lst[1] + "-" + name
    return name


def copybook(oid, o):
    cb = "LLWDM" + o["nr"]
    scal, lst = layout(oid, o)
    lines = [f"          05 {cb}."]
    fields, size = [], 0
    for f in scal:
        name, k, n = F[f]
        lines += cobol_line("10", name, k, n, 13)
        fields.append(ioarea_field(name, k, n))
        size += kind_size(k, n)
    if lst:
        arr, pre, item = lst
        lines += [f"             10 {(pre + '-COUNT').ljust(19)} PIC S9(4) USAGE COMP-5.",
                  f"             10 {pre}-ENTRY OCCURS 20 TIMES",
                  f"                  DEPENDING ON {pre}-COUNT."]
        size += 2
        sub, esize = [], 0
        for f in item:
            _, k, n = F[f]
            name = item_name(o, f)
            lines += cobol_line("15", name, k, n, 16)
            sub.append(ioarea_field(name, k, n))
            esize += kind_size(k, n)
        fields.append({"name": pre + "-COUNT", "type": "UI2", "length": 2})
        fields.append({"name": pre + "-ENTRY", "type": "GROUPDEPENDSON",
                       "maxOccurs": 20, "dependsOn": pre + "-COUNT", "fields": sub})
        size += 20 * esize
    for l in lines:
        assert len(l) <= 72, l
    return cb, "\n".join(lines) + "\n", fields, size


def esc(p):
    return p.replace("/", "~1")


def steps(oid, o, p, m, cb, size, resp_schema):
    base = f"#/paths/{esc(p)}/{m}/x-LWWProcessingSteps"
    st = []
    q = [i for i in o["inp"] if i[1] == "query"]
    pa = [i for i in o["inp"] if i[1] == "path"]
    bo = [i for i in o["inp"] if i[1] == "body"]

    def comb(items):
        out = []
        for it in items:
            name, req = it[0], it[2]
            c = {"type": "singleFields", "fromName": name,
                 "toName": F[target(it)][0]}
            if not req:
                c["required"] = False
            out.append(c)
        return out

    if q:
        st.append({"ServicePathRequestVariables": {"variables": {
            "$ref": f"{OAS1}/paths/{esc(p)}/{m}/parameters"}}})
    alloc = len(st)
    st.append({"AllocateIOArea": {"name": cb, "initWith": "0x00", "size": size,
                                  "fields": {"$ref": f"#/components/x-ioareas/{cb}/fields"}}})
    fields_ref = {"$ref": f"{base}/{alloc}/AllocateIOArea/fields"}
    # As CTF: the constant goes with the ID from the path; a path without
    # an ID gets it with the body, or else with the query parameters
    const = []
    if o.get("const"):
        const = [{"type": "constant", "constant": o["const"][1],
                  "toName": F[o["const"][0]][0]}]
        assert pa or bo or q, oid
    if q:
        st.append({"Mapping": {"from": {"$ref": f"{base}/0/ServicePathRequestVariables/variables"},
                               "to": fields_ref,
                               "combinations": comb(q) + (
                                   const if not pa and not bo else [])}})
    wrapper = "LWDC" + o["nr"]
    sfx = o.get("sfx", "")
    if pa:
        n = len(st)
        pcomb = [{"type": "singleFields", "toName": F[target(pa[0])][0]}] + const
        st.append({"ExtractIdFromPath": {"name": f"{wrapper}{sfx}_ID"}})
        st.append({"Mapping": {"from": {"$ref": f"{base}/{n}/ExtractIdFromPath"},
                               "to": fields_ref, "combinations": pcomb}})
    if bo:
        n = len(st)
        st.append({"ParseRequestJSON": {"name": f"{wrapper}{sfx}_JSNR"}})
        st.append({"Mapping": {"from": {"$ref": f"{base}/{n}/ParseRequestJSON"},
                               "to": fields_ref,
                               "combinations": comb(bo) + (
                                   const if not pa else [])}})
    alloc_ref = {"$ref": f"{base}/{alloc}/AllocateIOArea"}
    # syncOnReturn: LWW links with SYNCONRETURN. The wrappers are routed to
    # an AOR (DYNAMIC(YES)) and issue SYNCPOINT (ROLLBACK), which a DPL
    # program may only do then. CICS ignores it when the program runs local.
    # A form operation links to its local wrapper LWDWnnn instead, which
    # links to LWDCnnn with SYNCONRETURN itself.
    link = ({"program": "LWDW" + o["nr"], "passDataWith": "container"}
            if o.get("form") else
            {"program": wrapper, "passDataWith": "container", "syncOnReturn": True})
    st.append({"Link": {**link,
                        "in": [{"containerName": "LWW-LINK-PAR-03", **alloc_ref}],
                        "out": [{"containerName": "LWW-LINK-PAR-03", **alloc_ref}]}})
    cond = len(st)
    cbase = f"{base}/{cond}/Condition"

    def env_map():
        return [{"type": "singleFields", "fromName": F[f][0], "toName": f}
                for f in ENVELOPE]

    scal, lst = layout(oid, o)
    ok_map = env_map() + [{"type": "singleFields", "fromName": F[f][0], "toName": f}
                          for f in scal if f in o["out"]]
    if lst:
        arr, pre, item = lst
        ok_map.append({"type": "groupToArray", "fromGroupName": pre + "-ENTRY",
                       "toArrayName": arr,
                       "itemMappings": [{"type": "singleFields",
                                         "fromName": item_name(o, f),
                                         "toName": f}
                                        for f in o.get("lmap", item)]})

    def branch(name, schema, comb_, key):
        return [{"CreateObject": {"name": name, "properties": {
                    "$ref": f"{OAS1}/components/schemas/{schema}/properties"}}},
                {"Mapping": {"from": fields_ref,
                             "to": {"$ref": f"{cbase}/{key}/0/CreateObject/properties"},
                             "combinations": comb_}},
                {"JSONWriter": {"responseObject": {
                    "$ref": f"{cbase}/{key}/0/CreateObject"}}}]

    st.append({"Condition": {
        "name": f"{cb}{sfx}_OK", "source": fields_ref, "boolOperator": "AND",
        "expressions": [{"type": "fieldEqualsConstant", "fieldName": "RETURNCODE",
                         "constant": "00"}],
        "LWWProcessingStepsWhenTrue": branch(f"{wrapper}{sfx}_RET_OK", resp_schema,
                                             ok_map, "LWWProcessingStepsWhenTrue"),
        "LWWProcessingStepsWhenFalse": branch(f"{wrapper}{sfx}_RET_ERR",
                                              "ShortResponse", env_map(),
                                              "LWWProcessingStepsWhenFalse")}})
    return st


# ------------------------------------------------------------------ wrapper
WRAPPER = open(os.path.join(ROOT, "python", "wrapper.cbl.tpl")).read()


# A multipart body (POST /templateJcl): LWW leaves it to the program, and
# the modules have no CICS translator, so the local wrapper reads the fields
# jcl (base64, EBCDIC after CICS's conversion) and changeNote into the IO
# area. JCLLENGTH 0: no field jcl; more than the length of JCL: too large.
FORM_W = """       01  W-FORM.
           05  W-FORM-LEN            PIC S9(9) COMP-5.
           05  W-FORM-NOTE           PIC X(255).
"""
FORM_P = """      *===============================================================*
      * R050-READ-FORM: The form fields jcl and changeNote             *
      *===============================================================*
       R050-READ-FORM SECTION.
           MOVE 0 TO JCLLENGTH OF W-LLWDM@NR@
           MOVE LENGTH OF JCL OF W-LLWDM@NR@ TO W-FORM-LEN
           EXEC CICS
              WEB READ FORMFIELD('jcl')
                       NAMELENGTH(3)
                       VALUE(JCL OF W-LLWDM@NR@)
                       VALUELENGTH(W-FORM-LEN)
                       NOHANDLE
           END-EXEC
           EVALUATE TRUE
           WHEN EIBRESP = DFHRESP(NORMAL)
              MOVE W-FORM-LEN TO JCLLENGTH OF W-LLWDM@NR@
           WHEN EIBRESP = DFHRESP(LENGERR)
              COMPUTE JCLLENGTH OF W-LLWDM@NR@ =
                      LENGTH OF JCL OF W-LLWDM@NR@ + 1
           END-EVALUATE

           MOVE 0 TO CHANGENOTE-LEN OF W-LLWDM@NR@
           MOVE LENGTH OF W-FORM-NOTE TO W-FORM-LEN
           EXEC CICS
              WEB READ FORMFIELD('changeNote')
                       NAMELENGTH(10)
                       VALUE(W-FORM-NOTE)
                       VALUELENGTH(W-FORM-LEN)
                       NOHANDLE
           END-EXEC
           IF  (EIBRESP = DFHRESP(NORMAL) OR EIBRESP = DFHRESP(LENGERR))
           AND W-FORM-LEN > 0
              IF W-FORM-LEN > LENGTH OF W-FORM-NOTE
                 MOVE LENGTH OF W-FORM-NOTE TO W-FORM-LEN
              END-IF
              MOVE FUNCTION NATIONAL-OF(W-FORM-NOTE(1:W-FORM-LEN))
                TO CHANGENOTE-TEXT OF W-LLWDM@NR@
              COMPUTE CHANGENOTE-LEN OF W-LLWDM@NR@ = FUNCTION LENGTH(
                      FUNCTION NATIONAL-OF(W-FORM-NOTE(1:W-FORM-LEN)))
           END-IF
           .
       R050-READ-FORM-END.
           EXIT.

"""


# The tick (POST /schedulerTicks): after the commit, LWDC950 sends the queued
# mails in the same task, committing per mail, and answers how many
# (docs/11-iteration-7.md). A failing LINK only costs this tick's mails.
# SYNCONRETURN: LWDC950 commits per mail, which it may only do as DPL
# program when routed with it; CICS ignores it when LWDC950 runs local.
MAIL_W = """       01  W-MAIL-COUNT              PIC S9(4) COMP-5.
       01  W-MAIL-TRANSID            PIC X(4).
"""
MAIL_P = """      *===============================================================*
      * R200-SEND-MAIL: The queued mails, by LWDC950                  *
      *===============================================================*
       R200-SEND-MAIL SECTION.
           MOVE 0 TO W-MAIL-COUNT
           MOVE EIBTRNID TO W-MAIL-TRANSID
           EXEC CICS
              LINK PROGRAM('LWDC950')
                   COMMAREA(W-MAIL-COUNT)
                   LENGTH(LENGTH OF W-MAIL-COUNT)
                   TRANSID(W-MAIL-TRANSID)
                   SYNCONRETURN
                   NOHANDLE
           END-EXEC

           IF EIBRESP NOT = DFHRESP(NORMAL)
              MOVE 0 TO W-MAIL-COUNT
              MOVE EIBRESP  TO W-EIBRESP
              MOVE EIBRESP2 TO W-EIBRESP2
              MOVE 256 TO Vstring-length
              MOVE 1 TO W-MSGPTR
              STRING 'LINK LWDC950 ERROR ' W-EIBRESP ' ' W-EIBRESP2
                     DELIMITED BY SIZE
                INTO Vstring-text
                WITH POINTER W-MSGPTR
              COMPUTE Vstring-length = W-MSGPTR - 1
              CALL 'CEEMOUT' USING MSGSTR, MSGDEST, FC
           END-IF
           MOVE W-MAIL-COUNT TO MAILSSENT OF W-LLWDM@NR@
           .
       R200-SEND-MAIL-END.
           EXIT.

"""


def wrapper(oid, o, p, m, cb):
    nr = o["nr"]
    lst = o.get("lst")
    text = WRAPPER
    text = text.replace("      * @OP@", ("      * " + o.get("desc", f"{m.upper()} {p}.")
                                       ).ljust(70) + "*")
    text = text.replace("@NR@", nr)
    if o.get("created"):
        # A shared wrapper: 200, and 201 for the operation that creates
        fld, val = o["created"]
        text = text.replace("@OKCODE@", "200")
        text = text.replace("@CREATED@",
                            f"              IF {F[fld][0]} OF W-LLWDM{nr} = N'{val}'\n"
                            f"                 MOVE 201 TO W-OK-CODE\n"
                            f"              END-IF\n")
    else:
        text = text.replace("@OKCODE@", str(o.get("ok", 200)))
        text = text.replace("@CREATED@", "")
    text = text.replace("@SETCOUNT@",
                        f"              MOVE 20 TO {lst[1]}-COUNT OF W-LLWDM{nr}\n"
                        if lst else "")
    if o.get("mail"):
        text = text.replace("@MAILW@", MAIL_W)
        text = text.replace("@MAILCALL@", "                 PERFORM R200-SEND-MAIL\n")
        text = text.replace("@MAILP@", MAIL_P.replace("@NR@", nr))
    else:
        text = text.replace("@MAILW@", "")
        text = text.replace("@MAILCALL@", "")
        text = text.replace("@MAILP@", "")
    if o.get("submit"):
        text = text.replace("@SUBMITW@", "           COPY LWDSUBW.\n")
        text = text.replace("@CALLUSING@", f"W-LLWDM{nr} W-LLWDC910")
        text = text.replace("@AFTERCOMMIT@",
                            "                 IF RUNID OF W-LLWDC910 > 0\n"
                            "                    PERFORM R100-SUBMIT-JOB\n"
                            "                 END-IF\n")
        text = text.replace("@SUBMITP@", "           COPY LWDSUBP.\n\n")
    else:
        text = text.replace("@SUBMITW@", "")
        text = text.replace("@CALLUSING@", f"W-LLWDM{nr}")
        text = text.replace("@AFTERCOMMIT@", "")
        text = text.replace("@SUBMITP@", "")
    for l in text.splitlines():
        assert len(l) <= 72, (oid, l)
    return text


# The local wrapper LWDWnnn of a form operation runs in the routing region
# (DYNAMIC(NO)): it reads the form fields there, as WEB READ has no web
# request in the target region, and links to LWDCnnn with SYNCONRETURN.
LOCALWRAPPER = open(os.path.join(ROOT, "python", "localwrapper.cbl.tpl")).read()


def localwrapper(oid, o, p, m):
    nr = o["nr"]
    text = LOCALWRAPPER
    text = text.replace("      * @OP@", ("      * " + o.get("desc", f"{m.upper()} {p}.")
                                       ).ljust(70) + "*")
    text = text.replace("@NR@", nr)
    text = text.replace("@FORMW@", FORM_W)
    text = text.replace("@FORMP@", FORM_P.replace("@NR@", nr))
    for l in text.splitlines():
        assert len(l) <= 72, (oid, l)
    return text


def lked(name, extra):
    inc = "".join(f" INCLUDE SYSLIB({x})\n" for x in extra)
    return (f" MODE AMODE(31),RMODE(ANY)\n INCLUDE SYSLIB({name})\n{inc}"
            f" ENTRY {name}\n NAME {name}(R)\n")


def main():
    oas1 = yaml.safe_load(open(os.path.join(ROOT, "openapi", OAS1)))
    byid = {}
    for p, ops in oas1["paths"].items():
        for m, op in ops.items():
            if m != "summary":
                byid[op["operationId"]] = (p, m, op)
    paths, ioareas, done = {}, {}, {}
    for oid, o in OPS.items():
        p, m, op = byid[oid]
        cb, text, fields, size = copybook(oid, o)
        # Paths that share a program must share its IO area exactly
        if cb in done:
            assert done[cb] == text, (oid, cb)
        done[cb] = text
        with open(os.path.join(ROOT, "COPY", cb + ".cpy"), "w") as f:
            f.write(text)
        ok = str(o.get("ok", 200))
        rs = op["responses"][ok]["content"]["application/json"]["schema"]["$ref"]
        rs = rs.split("/")[-1]
        # Every response field must exist in the schema, and the other way round
        props = oas1["components"]["schemas"][rs]["properties"]
        scal, lst = layout(oid, o)
        mine = set(ENVELOPE) | {f for f in scal if f in o["out"]} | (
            {lst[0]} if lst else set())
        assert mine == set(props), (oid, mine ^ set(props))
        params = {x["name"] for x in op.get("parameters", [])}
        assert {i[0] for i in o["inp"] if i[1] != "body"} == params, (oid, params)
        paths.setdefault(p, {})[m] = {"x-LWWProcessingSteps":
                                      steps(oid, o, p, m, cb, size, rs)}
        ioareas[cb] = {"fields": fields, "copybook": {"name": cb}}
        wtext = wrapper(oid, o, p, m, cb)
        # ... and its wrapper
        if ("W" + cb) in done:
            assert done["W" + cb] == wtext, (oid, "wrapper")
        done["W" + cb] = wtext
        with open(os.path.join(ROOT, "COBOL", f"LWDC{o['nr']}.cbl"), "w") as f:
            f.write(wtext)
        progs = [(f"LWDC{o['nr']}", []), (f"LWDM{o['nr']}", ["DSNCLI"])]
        if o.get("form"):
            with open(os.path.join(ROOT, "COBOL", f"LWDW{o['nr']}.cbl"), "w") as f:
                f.write(localwrapper(oid, o, p, m))
            progs.append((f"LWDW{o['nr']}", []))
        for prog, extra in progs:
            with open(os.path.join(ROOT, "LKED", prog + ".lked"), "w") as f:
                f.write(lked(prog, extra))
    for prog, extra in SUPPORT.items():
        with open(os.path.join(ROOT, "LKED", prog + ".lked"), "w") as f:
            f.write(lked(prog, extra))
    # POST /token is LWW's own LWWADPLI, as in ctfdlww
    tok = "#/paths/~1token/post/x-LWWProcessingSteps"
    paths = {"/token": {"post": {"x-LWWProcessingSteps": [
        {"AllocateIOArea": {"fields": {"$ref": "#/components/x-ioareas/LWWADPLI/fields"},
                            "initWith": "0x00", "name": "LWWADPLI", "size": 1136}},
        {"ParseRequestJSON": {"name": "LWWADPLI_JSNR"}},
        {"Mapping": {"combinations": [
            {"fromName": "username", "toName": "USERNAME", "type": "singleFields"},
            {"fromName": "password", "toName": "PASSWORD", "type": "singleFields"}],
            "from": {"$ref": f"{tok}/1/ParseRequestJSON"},
            "to": {"$ref": f"{tok}/0/AllocateIOArea/fields"}}},
        {"Link": {"in": [{"$ref": f"{tok}/0/AllocateIOArea",
                          "containerName": "LWW-LINK-PAR-03"}],
                  "out": [{"$ref": f"{tok}/0/AllocateIOArea",
                           "containerName": "LWW-LINK-PAR-03"}],
                  "passDataWith": "container", "program": "LWWADPLI"}},
        {"CreateObject": {"name": "LWWADPLI_RET", "properties": {
            "$ref": f"{OAS1}/components/schemas/TokenResponse/properties"}}},
        {"Mapping": {"combinations": [
            {"fromName": "TOKEN", "toName": "token", "type": "singleFields"}],
            "from": {"$ref": f"{tok}/0/AllocateIOArea/fields"},
            "to": {"$ref": f"{tok}/4/CreateObject/properties"}}},
        {"JSONWriter": {"responseObject": {"$ref": f"{tok}/4/CreateObject"}}}]}},
        **paths}
    ioareas = {"LWWADPLI": {"fields": [
        {"name": "USERNAME", "type": "CHARARRAY037", "length": 8},
        {"name": "PASSWORD", "type": "VARCHAR037", "length": 100},
        {"name": "TOKEN", "type": "VARCHAR037", "length": 1024}]}, **ioareas}
    doc = {"paths": paths, "components": {"x-ioareas": ioareas}}
    text = yaml.dump(doc, Dumper=NoAliasDumper, sort_keys=False, width=100,
                     allow_unicode=True)
    text = text.replace("initWith: '0x00'", "initWith: 0x00")
    with open(os.path.join(ROOT, "openapi", OAS2), "w") as f:
        f.write(text)
    print(len(OPS), "operations:",
          ", ".join(sorted({f"LWDC{o['nr']}" for o in OPS.values()})))
    return sorted(OPS)


class NoAliasDumper(yaml.SafeDumper):
    # LWW doesn't read YAML anchors and aliases (&id001, *id001): write a
    # reference used in several places out in full each time, as in CTF
    def ignore_aliases(self, data):
        return True


if __name__ == "__main__":
    main()
