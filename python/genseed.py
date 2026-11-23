"""Generate DDL/SEEDDATA.sql. Run from the repository root:
python python/genseed.py"""
import os
import sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = "{{SCHEMA}}.{{%s_TBNAME}}"
SEED = "'SEED',CURRENT TIMESTAMP,'SEED',CURRENT TIMESTAMP"
APP = [f"            (SELECT APPID FROM {T % 'APPLICATIONS'}",
       "              WHERE APPCODE='DEMO')"]
out = ["-- Seed data for iteration 1: allowlists and a demo application with",
       "-- three environments, two job templates and two versions. Run after",
       "-- AA000004-AA000023. Not rerunnable: run it once per environment.",
       "",
       "-- Set SQLID",
       "   SET CURRENT SQLID='{{SQLID}}';",
       ""]

def stmt(lines):
    for l in lines:
        assert len(l) <= 72, l
    out.extend(lines)

def q(s):
    return "'" + s.replace("'", "''") + "'"

out.append("-- Allowlists: RACF groups and deploy userids")
for grp, desc in [("{{DEMOACCESSGROUP}}", "Demo: members"),
                  ("{{DEMOOWNERGROUP}}", "Demo: owners"),
                  ("{{DEMOAPPROVERGROUP}}", "Demo: PRD approvers")]:
    stmt([f"   INSERT INTO {T % 'REFTABLES'}",
          f"     VALUES('RACFGRP','{grp}','{desc}',",
          f"            {SEED});"])
stmt([f"   INSERT INTO {T % 'REFTABLES'}",
      "     VALUES('DEPLUSER','{{DEPLOYUSER}}','Demo deploy userid',",
      f"            {SEED});", ""])

out.append("-- The demo application")
stmt([f"   INSERT INTO {T % 'APPLICATIONS'}",
      "     (APPCODE, APPNAME, DESCRIPTION, ACCESSGROUP, OWNERGROUP,",
      "      CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE)",
      "     VALUES('DEMO', 'Demo application',",
      "            'Shows how LWD runs a deployment',",
      "            '{{DEMOACCESSGROUP}}', '{{DEMOOWNERGROUP}}',",
      f"            {SEED});", ""])

out.append("-- DEV and TST without approval, PRD with two approvers. TST and PRD")
out.append("-- need the version to have succeeded in the environment before.")
for code, name, order, gate, appr, grp, n in [
        ("DEV", "Development", 1, "N", "N", "CAST(NULL AS GRAPHIC(8))", 0),
        ("TST", "Test", 2, "Y", "N", "CAST(NULL AS GRAPHIC(8))", 0),
        ("PRD", "Production", 3, "Y", "Y", "'{{DEMOAPPROVERGROUP}}'", 2)]:
    stmt([f"   INSERT INTO {T % 'ENVIRONMENTS'}",
          "     (APPID, ENVCODE, ENVNAME, SORTORDER, PROMOGATE, DEPLOYUSER,",
          "      APPROVALREQ, APPROVERGROUP, APPROVALCOUNT, ENVSTATE,",
          "      CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE)",
          f"     SELECT APPID, '{code}', '{name}', {order}, '{gate}',",
          f"            '{{{{DEPLOYUSER}}}}', '{appr}',",
          f"            {grp}, {n}, 'N',",
          f"            {SEED}",
          f"       FROM {T % 'APPLICATIONS'}",
          "      WHERE APPCODE='DEMO';"])
out.append("")

out.append("-- Versions: V1.0.0 works, V1.0.1-BAD makes job 2 end with RC 8")
for vname, loc, desc in [("V1.0.0", "V100", "First version"),
                         ("V1.0.1-BAD", "V101", "Fails in job 2")]:
    stmt([f"   INSERT INTO {T % 'VERSIONS'}",
          "     (APPID, VERSIONNAME, LOCTYPE, LOCATION, DESCRIPTION,",
          "      VERSIONSTATUS,",
          "      CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE)",
          f"     SELECT APPID, '{vname}', 'D',",
          f"            '{{{{DEMOHLQ}}}}.{loc}',",
          f"            '{desc}', 'A',",
          f"            {SEED}",
          f"       FROM {T % 'APPLICATIONS'}",
          "      WHERE APPCODE='DEMO';"])
out.append("")

out.append("-- Variables: DEMORC on application and version level, TARGET per")
out.append("-- environment")
def var(name, value, desc, env=None, ver=None):
    lines = [f"   INSERT INTO {T % 'VARIABLES'}",
             "     (APPID, ENVID, VERSIONID, VARNAME, VARVALUE, DESCRIPTION,",
             "      CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE)",
             "     SELECT A.APPID,"]
    if env:
        lines += [f"            (SELECT ENVID FROM {T % 'ENVIRONMENTS'} E",
                  "              WHERE E.APPID = A.APPID",
                  f"                AND E.ENVCODE = '{env}'),"]
    else:
        lines += ["            CAST(NULL AS INTEGER),"]
    if ver:
        lines += [f"            (SELECT VERSIONID FROM {T % 'VERSIONS'} V",
                  "              WHERE V.APPID = A.APPID",
                  f"                AND V.VERSIONNAME = '{ver}'),"]
    else:
        lines += ["            CAST(NULL AS INTEGER),"]
    lines += [f"            '{name}', {q(value)},",
              f"            {q(desc)},",
              f"            {SEED}",
              f"       FROM {T % 'APPLICATIONS'} A",
              "      WHERE A.APPCODE='DEMO';"]
    stmt(lines)
var("DEMORC", "0", "Return code of job 2")
var("DEMORC", "8", "This version fails in job 2", ver="V1.0.1-BAD")
for env in ("DEV", "TST", "PRD"):
    var("TARGET", "{{DEMOHLQ}}." + env, "Where it would go", env=env)
out.append("")

TPL = [("Show the version", 1, 0, [
            "//SHOW     EXEC PGM=IEBGENER",
            "//SYSPRINT DD SYSOUT=*",
            "//SYSIN    DD DUMMY",
            "//SYSUT2   DD SYSOUT=*",
            "//SYSUT1   DD *",
            "APPLICATION ${LWDAPP} VERSION ${LWDVER}",
            "LOCATION    ${LWDLOC}",
            "ENVIRONMENT ${LWDENV} TARGET ${TARGET}",
            "DEPLOYMENT  ${LWDDEPL}",
            "/*"]),
       ("Set the return code", 2, 4, [
            "//SETRC    EXEC PGM=IDCAMS",
            "//SYSPRINT DD SYSOUT=*",
            "//SYSIN    DD *",
            "  SET MAXCC = ${DEMORC}",
            "/*"])]
out.append("-- Job templates, each with revision 1")
for name, order, maxrc, lines in TPL:
    stmt([f"   INSERT INTO {T % 'TEMPLATES'}",
          "     (APPID, TEMPLATENAME, SORTORDER, MAXRC, CURRENTREV,",
          "      TEMPLATESTATUS,",
          "      CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE)",
          f"     SELECT APPID, '{name}', {order}, {maxrc}, 1, 'A',",
          f"            {SEED}",
          f"       FROM {T % 'APPLICATIONS'}",
          "      WHERE APPCODE='DEMO';"])
    where = [f"       FROM {T % 'TEMPLATES'} T",
             "      WHERE T.APPID ="] + APP + [
             f"        AND T.TEMPLATENAME = '{name}';"]
    stmt([f"   INSERT INTO {T % 'TEMPLATEREVS'}",
          "     (TEMPLATEID, REVISION, CHANGENOTE, LINECOUNT,",
          "      CREATEDBY, CREATEDDATE, UPDATEDBY, UPDATEDDATE)",
          f"     SELECT T.TEMPLATEID, 1, 'Seed data', {len(lines)},",
          f"            {SEED}"] + where)
    for n, line in enumerate(lines, 1):
        stmt([f"   INSERT INTO {T % 'TEMPLATELINES'}",
              f"     SELECT T.TEMPLATEID, 1, {n},",
              f"            {q(line)},",
              f"            {SEED}"] + where)
out += ["", "   COMMIT;"]
open(os.path.join(ROOT, "DDL", "SEEDDATA.sql"), "w").write("\n".join(out) + "\n")
