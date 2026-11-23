"""Generate lwdeploy DDL members, $INFO.txt and the table part of envs/t01.yaml
in the style of ctfdlww/DDL."""
import os
import sys

# Run from the repository root: python python/genddl.py [outdir]
# Writes DDL/AA000004-AA000023, DDL/$INFO.txt, COPY/TBLWDnnn.cpy and
# envs-tables.yaml (the table names for envs/t01.yaml) under outdir,
# which is the repository root by default.
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(
    os.path.dirname(os.path.abspath(__file__)))

IDENT = ("INTEGER NOT NULL GENERATED ALWAYS\n"
         "          AS IDENTITY\n"
         "             (START WITH 1, INCREMENT BY 1, CACHE 20, NO CYCLE,\n"
         "              NO ORDER, MAXVALUE 2147483647, MINVALUE 1)")

# name, nr, description, columns [(name, type, nullable)], pk, other indexes
# [(cols, unique)], fks [(cols, parent, parentcols)], tablespace size
T = []


def t(name, nr, desc, cols, pk, ix=(), fk=(), pri=40, sec=40, seq=None, tail=()):
    # tail: columns added later with ALTER TABLE ADD, so after the audit
    # columns, where DB2 puts them; a new table gets them in the same place
    T.append(dict(name=name, nr=nr, desc=desc, cols=cols, pk=pk, ix=list(ix),
                  fk=list(fk), pri=pri, sec=sec, seq=seq, tail=list(tail)))


N = True   # nullable
R = False  # not null

t("REFTABLES", "001", "Key/value lists: allowlists and settings", [
    ("TABLEID", "GRAPHIC(8)", R), ("TABKEY", "GRAPHIC(8)", R),
    ("TABVALUE", "VARGRAPHIC(255)", N)], ["TABLEID", "TABKEY"])

t("USERS", "002", "Everyone who ever called LWD", [
    ("USERID", "GRAPHIC(8)", R), ("EMAIL", "VARGRAPHIC(254)", N),
    ("NOTIFYAPPROVE", "GRAPHIC(1)", R),
    ("NOTIFYOWN", "GRAPHIC(1)", R), ("NOTIFYAPP", "GRAPHIC(1)", R),
    ("GROUPSCHECKED", "TIMESTAMP", N)], ["USERID"])

t("USERGROUPS", "003", "Cache of the allowlisted groups a user has access through", [
    ("USERID", "GRAPHIC(8)", R), ("RACFGROUP", "GRAPHIC(8)", R)],
  ["USERID", "RACFGROUP"],
  ix=[(["RACFGROUP"], False)],
  fk=[(["USERID"], "USERS", ["USERID"])])

t("APPLICATIONS", "004", "Applications", [
    ("APPID", IDENT, None), ("APPCODE", "GRAPHIC(8)", R),
    ("APPNAME", "VARGRAPHIC(60)", R), ("DESCRIPTION", "VARGRAPHIC(1000)", N),
    ("ACCESSGROUP", "GRAPHIC(8)", R), ("OWNERGROUP", "GRAPHIC(8)", R)],
  ["APPID"],
  ix=[(["APPCODE"], True), (["ACCESSGROUP"], False), (["OWNERGROUP"], False)])

t("VERSIONS", "005", "Registered versions", [
    ("VERSIONID", IDENT, None), ("APPID", "INTEGER", R),
    ("VERSIONNAME", "VARGRAPHIC(30)", R), ("LOCTYPE", "GRAPHIC(1)", R),
    ("LOCATION", "VARGRAPHIC(255)", R), ("DESCRIPTION", "VARGRAPHIC(1000)", N),
    ("VERSIONSTATUS", "GRAPHIC(1)", R)],
  ["VERSIONID"],
  ix=[(["APPID", "VERSIONNAME"], True), (["APPID", "CREATEDDATE"], False)],
  fk=[(["APPID"], "APPLICATIONS", ["APPID"])])

t("ENVIRONMENTS", "006", "Environments of an application", [
    ("ENVID", IDENT, None), ("APPID", "INTEGER", R),
    ("ENVCODE", "GRAPHIC(8)", R), ("ENVNAME", "VARGRAPHIC(60)", R),
    ("DESCRIPTION", "VARGRAPHIC(1000)", N), ("SORTORDER", "SMALLINT", R),
    ("PROMOGATE", "GRAPHIC(1)", R), ("DEPLOYUSER", "GRAPHIC(8)", N),
    ("APPROVALREQ", "GRAPHIC(1)", R), ("APPROVERGROUP", "GRAPHIC(8)", N),
    ("APPROVALCOUNT", "SMALLINT", R), ("DEPLOYERGROUP", "GRAPHIC(8)", N),
    ("ACTIVEDEPLID", "INTEGER", N), ("CURRENTDEPLID", "INTEGER", N),
    ("CURRENTVERSIONID", "INTEGER", N), ("ENVSTATE", "GRAPHIC(1)", R)],
  ["ENVID"],
  ix=[(["APPID", "ENVCODE"], True), (["APPID", "SORTORDER"], False),
      (["CURRENTVERSIONID"], False)],
  fk=[(["APPID"], "APPLICATIONS", ["APPID"]),
      (["CURRENTVERSIONID"], "VERSIONS", ["VERSIONID"])],
  # Iteration 4 (DDL/ALTITR4): JES2 node the jobs run on (/*XEQ)
  tail=[("EXECNODE", "GRAPHIC(8)", N)])

t("VARIABLES", "007", "Variables on application, environment or version level", [
    ("VARID", IDENT, None), ("APPID", "INTEGER", R), ("ENVID", "INTEGER", N),
    ("VERSIONID", "INTEGER", N), ("VARNAME", "VARGRAPHIC(16)", R),
    ("VARVALUE", "VARGRAPHIC(255)", R), ("DESCRIPTION", "VARGRAPHIC(255)", N)],
  ["VARID"],
  ix=[(["APPID", "ENVID", "VERSIONID", "VARNAME"], True), (["ENVID"], False),
      (["VERSIONID"], False)],
  fk=[(["APPID"], "APPLICATIONS", ["APPID"]),
      (["ENVID"], "ENVIRONMENTS", ["ENVID"]),
      (["VERSIONID"], "VERSIONS", ["VERSIONID"])])

t("TEMPLATES", "008", "Job templates of an application", [
    ("TEMPLATEID", IDENT, None), ("APPID", "INTEGER", R),
    ("TEMPLATENAME", "VARGRAPHIC(60)", R), ("SORTORDER", "SMALLINT", R),
    ("MAXRC", "SMALLINT", R), ("CURRENTREV", "SMALLINT", R),
    ("TEMPLATESTATUS", "GRAPHIC(1)", R)],
  ["TEMPLATEID"],
  ix=[(["APPID", "SORTORDER"], False)],
  fk=[(["APPID"], "APPLICATIONS", ["APPID"])])

t("TEMPLATEREVS", "009", "Every saved revision of a job template", [
    ("TEMPLATEID", "INTEGER", R), ("REVISION", "SMALLINT", R),
    ("CHANGENOTE", "VARGRAPHIC(255)", N), ("LINECOUNT", "SMALLINT", R)],
  ["TEMPLATEID", "REVISION"],
  fk=[(["TEMPLATEID"], "TEMPLATES", ["TEMPLATEID"])])

t("TEMPLATELINES", "010", "JCL lines of a template revision", [
    ("TEMPLATEID", "INTEGER", R), ("REVISION", "SMALLINT", R),
    ("LINENUM", "SMALLINT", R), ("LINETEXT", "VARGRAPHIC(80)", R)],
  ["TEMPLATEID", "REVISION", "LINENUM"],
  fk=[(["TEMPLATEID", "REVISION"], "TEMPLATEREVS", ["TEMPLATEID", "REVISION"])],
  pri=720, sec=720)

t("DEPLOYMENTS", "011", "One version of one application into one environment", [
    ("DEPLID", IDENT, None), ("APPID", "INTEGER", R), ("ENVID", "INTEGER", R),
    ("VERSIONID", "INTEGER", R), ("DEPLSTATUS", "GRAPHIC(1)", R),
    ("STARTAFTER", "TIMESTAMP", R), ("REQUESTNOTE", "VARGRAPHIC(255)", N),
    ("DEPLOYUSER", "GRAPHIC(8)", R), ("APPROVERGROUP", "GRAPHIC(8)", N),
    ("APPROVALCOUNT", "SMALLINT", R), ("APPROVEDCOUNT", "SMALLINT", R),
    ("STARTEDDATE", "TIMESTAMP", N), ("ENDEDDATE", "TIMESTAMP", N)],
  ["DEPLID"],
  ix=[(["APPID", "CREATEDDATE"], False),
      (["ENVID", "DEPLSTATUS", "STARTAFTER"], False),
      (["VERSIONID", "ENVID", "DEPLSTATUS"], False),
      (["DEPLSTATUS", "APPROVERGROUP", "CREATEDDATE"], False),
      (["CREATEDBY", "CREATEDDATE"], False)],
  fk=[(["APPID"], "APPLICATIONS", ["APPID"]),
      (["ENVID"], "ENVIRONMENTS", ["ENVID"]),
      (["VERSIONID"], "VERSIONS", ["VERSIONID"])])

t("DEPLJOBS", "012", "The jobs of a deployment, in order", [
    ("DEPLID", "INTEGER", R), ("JOBNO", "SMALLINT", R),
    ("TEMPLATEID", "INTEGER", R), ("TEMPLATEREV", "SMALLINT", R),
    ("JOBTITLE", "VARGRAPHIC(60)", R), ("MAXRC", "SMALLINT", R),
    ("JOBSTATUS", "GRAPHIC(1)", R), ("LINECOUNT", "SMALLINT", R),
    ("LASTRUNID", "INTEGER", N), ("SKIPREASON", "VARGRAPHIC(255)", N)],
  ["DEPLID", "JOBNO"],
  ix=[(["TEMPLATEID", "TEMPLATEREV"], False)],
  fk=[(["DEPLID"], "DEPLOYMENTS", ["DEPLID"]),
      (["TEMPLATEID", "TEMPLATEREV"], "TEMPLATEREVS", ["TEMPLATEID", "REVISION"])])

t("JCLLINES", "013", "Frozen JCL of a job of a deployment", [
    ("DEPLID", "INTEGER", R), ("JOBNO", "SMALLINT", R),
    ("LINENUM", "SMALLINT", R), ("LINETEXT", "VARGRAPHIC(80)", R)],
  ["DEPLID", "JOBNO", "LINENUM"],
  fk=[(["DEPLID", "JOBNO"], "DEPLJOBS", ["DEPLID", "JOBNO"])],
  pri=7200, sec=7200)

t("JOBRUNS", "014", "One submission of a job; a retry is a new run", [
    ("RUNID", "INTEGER", R), ("DEPLID", "INTEGER", R), ("JOBNO", "SMALLINT", R),
    ("JOBNAME", "GRAPHIC(8)", R), ("RUNSTATUS", "GRAPHIC(1)", R),
    ("JOBRESULT", "GRAPHIC(1)", N), ("JESJOBID", "GRAPHIC(8)", N),
    ("SUBMITTEDDATE", "TIMESTAMP", N), ("ENDEDDATE", "TIMESTAMP", N),
    ("JOBRC", "SMALLINT", N), ("ABENDCODE", "GRAPHIC(5)", N),
    ("JOBMESSAGE", "VARGRAPHIC(72)", N), ("OUTPUTSTATUS", "GRAPHIC(1)", R),
    ("JOBHASH", "BINARY(32)", N)],
  ["RUNID"],
  ix=[(["JOBNAME"], True), (["DEPLID", "JOBNO"], False),
      (["RUNSTATUS", "SUBMITTEDDATE"], False),
      (["OUTPUTSTATUS", "ENDEDDATE"], False)],
  fk=[(["DEPLID", "JOBNO"], "DEPLJOBS", ["DEPLID", "JOBNO"])],
  seq="""-- Create sequence for RUNID. The key is needed before the insert,
-- because the job name contains it (JOBPRFX + RUNID in base 36).
   CREATE SEQUENCE {{SCHEMA}}.{{JOBRUNS_SEQNAME}}
      AS INTEGER
      START WITH 1 INCREMENT BY 1
      MINVALUE 1 MAXVALUE 2147483647
      NO CYCLE CACHE 20 NO ORDER;
""")

t("JOBSTEPS", "015", "Return code or abend per step of a run", [
    ("RUNID", "INTEGER", R), ("STEPNO", "SMALLINT", R),
    ("STEPNAME", "GRAPHIC(8)", R), ("PROCSTEP", "GRAPHIC(8)", N),
    ("PGMNAME", "GRAPHIC(8)", N), ("STEPRC", "SMALLINT", N),
    ("ABENDCODE", "GRAPHIC(5)", N), ("FLUSHED", "GRAPHIC(1)", R)],
  ["RUNID", "STEPNO"],
  fk=[(["RUNID"], "JOBRUNS", ["RUNID"])])

t("SPOOLFILES", "016", "Spool files collected for a run", [
    ("RUNID", "INTEGER", R), ("FILENO", "SMALLINT", R),
    ("DDNAME", "GRAPHIC(8)", R), ("STEPNAME", "GRAPHIC(8)", N),
    ("PROCSTEP", "GRAPHIC(8)", N), ("LINECOUNT", "INTEGER", R),
    ("TRUNCATED", "GRAPHIC(1)", R)],
  ["RUNID", "FILENO"],
  fk=[(["RUNID"], "JOBRUNS", ["RUNID"])])

t("SPOOLLINES", "017", "Lines of a collected spool file", [
    ("RUNID", "INTEGER", R), ("FILENO", "SMALLINT", R),
    ("LINENUM", "INTEGER", R), ("LINETEXT", "VARGRAPHIC(255)", R)],
  ["RUNID", "FILENO", "LINENUM"],
  fk=[(["RUNID", "FILENO"], "SPOOLFILES", ["RUNID", "FILENO"])],
  pri=72000, sec=72000)

t("APPROVALS", "018", "Approval decisions; one per person per deployment", [
    ("DEPLID", "INTEGER", R), ("USERID", "GRAPHIC(8)", R),
    ("DECISION", "GRAPHIC(1)", R), ("COMMENTTEXT", "VARGRAPHIC(255)", N)],
  ["DEPLID", "USERID"],
  ix=[(["USERID"], False)],
  fk=[(["DEPLID"], "DEPLOYMENTS", ["DEPLID"]),
      (["USERID"], "USERS", ["USERID"])])

t("DEPLEVENTS", "019", "History of a deployment: who did what and why", [
    ("DEPLID", "INTEGER", R), ("EVENTNO", "SMALLINT", R),
    ("EVENTTYPE", "GRAPHIC(1)", R), ("JOBNO", "SMALLINT", N),
    ("COMMENTTEXT", "VARGRAPHIC(255)", N)],
  ["DEPLID", "EVENTNO"],
  fk=[(["DEPLID"], "DEPLOYMENTS", ["DEPLID"])])

t("MAILQUEUE", "020", "Notification mails to send", [
    ("MAILID", IDENT, None), ("USERID", "GRAPHIC(8)", R),
    ("EMAIL", "VARGRAPHIC(254)", R), ("DEPLID", "INTEGER", N),
    ("MAILTYPE", "GRAPHIC(1)", R), ("SUBJECT", "VARGRAPHIC(100)", R),
    ("BODY", "VARGRAPHIC(1000)", R), ("MAILSTATUS", "GRAPHIC(1)", R),
    ("ATTEMPTS", "SMALLINT", R), ("SENTDATE", "TIMESTAMP", N)],
  ["MAILID"],
  ix=[(["MAILSTATUS", "CREATEDDATE"], False), (["USERID"], False),
      (["DEPLID"], False)],
  fk=[(["USERID"], "USERS", ["USERID"]),
      (["DEPLID"], "DEPLOYMENTS", ["DEPLID"])])

AUDIT = [("CREATEDBY", "GRAPHIC(8)", R), ("CREATEDDATE", "TIMESTAMP", R),
         ("UPDATEDBY", "GRAPHIC(8)", R), ("UPDATEDDATE", "TIMESTAMP", R)]

TS = """-- Create {low} tablespace
   CREATE TABLESPACE {{{{{N}_TBSNAME}}}}
                       IN {{{{DBNAME}}}}
                       USING STOGROUP {{{{STOGROUP}}}}
                       PRIQTY {pri} SECQTY {sec}
                       ERASE  NO
                       FREEPAGE 0 PCTFREE 5 FOR UPDATE 0
                       GBPCACHE CHANGED
                       TRACKMOD YES
                       MAXPARTITIONS 254
                       LOGGED
                       DSSIZE 4 G
                       SEGSIZE 4
                       BUFFERPOOL BP0
                       LOCKSIZE ANY
                       LOCKMAX SYSTEM
                       CLOSE YES
                       COMPRESS {compress}
                       CCSID      UNICODE
                       DEFINE YES
                       MAXROWS 255
                       INSERT ALGORITHM 0;
"""

IXTAIL = """     USING STOGROUP {{STOGROUP}}
     PRIQTY -1 SECQTY -1
     ERASE  NO
     FREEPAGE 0 PCTFREE 10
     GBPCACHE CHANGED
     NOT CLUSTER
     COMPRESS NO
     INCLUDE NULL KEYS
     BUFFERPOOL BP0
     CLOSE NO
     COPY NO
     DEFER NO
     DEFINE YES
     PIECESIZE 2 G;
"""


def collist(cols, indent, asc=False):
    w = max(len(c) for c in cols)
    out = []
    for i, c in enumerate(cols):
        s = c.ljust(w) + " ASC" if asc else c
        s = s.rstrip() if not asc else s
        out.append((" " * indent if i else "") + s)
    return (",\n").join(out)


def member(tb, members):
    n, low = tb["name"], tb["name"].lower()
    cols = tb["cols"] + AUDIT + tb["tail"]
    w = max(len(c[0]) for c in cols) + 1
    lines = []
    for c in cols:
        if c[2] is None:
            lines.append(c[0].ljust(w) + c[1])
        else:
            lines.append(c[0].ljust(w) + c[1] + ("" if c[2] else " NOT NULL"))
    coldef = ",\n       ".join(lines)
    big = tb["name"] in ("SPOOLLINES", "JCLLINES", "TEMPLATELINES")
    s = f"-- Create {low} table in lwd database.\n\n"
    s += "-- Set SQLID\n   SET CURRENT SQLID='{{SQLID}}';\n\n"
    s += TS.format(low=low, N=n, pri=tb["pri"], sec=tb["sec"],
                   compress="YES" if big else "NO")
    s += f"\n-- Create {low} table\n"
    s += f"   CREATE TABLE {{{{SCHEMA}}}}.{{{{{n}_TBNAME}}}}\n"
    s += f"      ({coldef},\n"
    s += f"       CONSTRAINT {n}KEY\n"
    s += f"       PRIMARY KEY ({collist(tb['pk'], 20)}))\n"
    s += f"      IN {{{{DBNAME}}}}.{{{{{n}_TBSNAME}}}}\n"
    s += ("      PARTITION BY SIZE\n      AUDIT NONE\n      DATA CAPTURE NONE\n"
          "      CCSID      UNICODE\n      NOT VOLATILE\n      APPEND NO;\n")
    ixs = [(tb["pk"], True, "for primary key")] + \
          [(c, u, "on " + ", ".join(c)) for c, u in tb["ix"]]
    for i, (c, u, what) in enumerate(ixs, 1):
        s += f"\n-- Create {low} {'unique ' if u and i > 1 else ''}index {what}\n"
        s += (f"   CREATE {'UNIQUE ' if u else ''}INDEX "
              f"{{{{SCHEMA}}}}.{{{{{n}_IXNAME{i}}}}}\n")
        s += f"      ON {{{{SCHEMA}}}}.{{{{{n}_TBNAME}}}}\n"
        s += f"      ({collist(c, 7, asc=True)})\n"
        s += IXTAIL
    for i, (c, parent, pc) in enumerate(tb["fk"], 1):
        s += f"\n-- Create foreign key on {', '.join(c)}\n"
        s += f"   ALTER TABLE {{{{SCHEMA}}}}.{{{{{n}_TBNAME}}}}\n"
        s += f"     FOREIGN KEY {n[:6]}_FK{i} ({', '.join(c)})\n"
        s += f"     REFERENCES {{{{SCHEMA}}}}.{{{{{parent}_TBNAME}}}}\n"
        s += f"       ({', '.join(pc)})\n"
        s += "     ON DELETE RESTRICT ENFORCED;\n"
        assert members[parent] < members[n], (n, parent)
    if tb["seq"]:
        s += "\n" + tb["seq"]
    s += "\n   COMMIT;"
    return s, len(ixs)


def main():
    os.makedirs(os.path.join(OUT, "DDL"), exist_ok=True)
    members = {tb["name"]: 4 + i for i, tb in enumerate(T)}
    yaml = []
    info = ["Member   Who When YMD Description",
            "-------- --- -------- --------------------------------------------------",
            "AA000001 BTK 26-11-12 Grant permission for CREATESG,CREATEDBA, use of",
            "                      bufferpools and execute on packages.",
            "AA000002 BTK 26-11-12 Create storage group for lwd database",
            "AA000003 BTK 26-11-12 Create lwd database"]
    w = max(len(tb["name"]) for tb in T)
    for tb in T:
        mem = f"AA{members[tb['name']]:06d}"
        s, nix = member(tb, members)
        with open(os.path.join(OUT, "DDL", mem + ".sql"), "w") as f:
            f.write(s)
        info.append(f"{mem} BTK 26-11-12 00 Create {tb['name'].lower().ljust(w)} table")
        n = tb["name"]
        yaml.append(f"{n}_TBNR: '{tb['nr']}'")
        yaml.append(f"{n}_TBSNAME: TSLWD{{{{{n}_TBNR}}}}")
        yaml.append(f"{n}_TBNAME: TBLWD{{{{{n}_TBNR}}}}")
        for i in range(1, nix + 1):
            yaml.append(f"{n}_IXNAME{i}: IXLWD{{{{{n}_TBNR}}}}{i}")
        if tb["seq"]:
            yaml.append(f"{n}_SEQNAME: SQLWD{{{{{n}_TBNR}}}}")
    info.append("SETTINGS BTK 26-11-12 00 Every SETTINGS entry in one member, rerunnable")
    info.append("SEEDDATA BTK 26-11-12 00 Seed data for iteration 1: allowlists and a")
    info.append("                      demo application")
    info.append("SETTINGS BTK 26-11-13 01 SCHEDUSR, the userid of the scheduler (it. 2)")
    info.append("SEEDDATA BTK 26-11-13 01 The demo PRD needs two approvals")
    info.append("SEEDITR2 BTK 26-11-13 00 The demo PRD needs two approvals, for an")
    info.append("                      environment seeded in iteration 1")
    info.append("SETTINGS BTK 26-11-14 02 It. 3: no CICS writer. It. 4: where the")
    info.append("                      result step finds LWD's REST API, not DB2")
    info.append("ALTITR4  BTK 26-11-14 00 ENVIRONMENTS.EXECNODE, for a table created")
    info.append("                      before iteration 4")
    with open(os.path.join(OUT, "DDL", "$INFO.txt"), "w") as f:
        f.write("\n".join(info) + "\n")
    os.makedirs(os.path.join(OUT, "python"), exist_ok=True)
    with open(os.path.join(OUT, "python", "envs-tables.yaml"), "w") as f:
        f.write("\n".join(yaml) + "\n")
    for tb in T:
        print(tb["nr"], tb["name"], f"AA{members[tb['name']]:06d}",
              "ix", 1 + len(tb["ix"]), "fk", len(tb["fk"]))


main()


def dclgen(tb):
    n = "TBLWD" + tb["nr"]
    cols = [(c[0], "INTEGER" if c[2] is None else c[1], False if c[2] is None else c[2])
            for c in tb["cols"] + AUDIT + tb["tail"]]
    s = ["      " + "*" * 66,
         f"      * DCLGEN TABLE({n})".ljust(71) + "*",
         "      * LAYOUT OF DDL MEMBER, TO BE COMPARED WITH A REAL DCLGEN".ljust(71) + "*",
         "      " + "*" * 66,
         f"           EXEC SQL DECLARE {n} TABLE"]
    for i, (c, t, nul) in enumerate(cols):
        sep = "( " if i == 0 else "  "
        tail = "," if i < len(cols) - 1 else ""
        s.append(f"           {sep}{c.ljust(30)} {t}{'' if nul else ' NOT NULL'}{tail}")
    s.append("           ) END-EXEC.")
    s.append(f"       01  DCL{n}.")
    for c, t, nul in cols:
        if t == "INTEGER":
            pic = "PIC S9(9) USAGE COMP-5."
        elif t == "SMALLINT":
            pic = "PIC S9(4) USAGE COMP-5."
        elif t == "TIMESTAMP":
            pic = "PIC X(26)."
        elif t.startswith("GRAPHIC"):
            pic = f"PIC N({t[8:-1]})."
        elif t.startswith("BINARY"):
            pic = f"PIC X({t[7:-1]})."
        elif t.startswith("VARGRAPHIC"):
            ln = t[11:-1]
            s.append(f"           10 {c}.")
            s.append(f"              49 {c}-LEN PIC S9(4) USAGE COMP-5.")
            s.append(f"              49 {c}-TEXT PIC N({ln}).")
            pic = None
        else:
            raise ValueError(t)
        if pic:
            s.append(f"           10 {c.ljust(20)} {pic}")
        if nul:
            s.append(f"           10 {(c + '-IND').ljust(20)} PIC S9(4) USAGE COMP-5.")
    for l in s:
        assert len(l) <= 72, l
    return "\n".join(s) + "\n"


os.makedirs(os.path.join(OUT, "COPY"), exist_ok=True)
for tb in T:
    with open(os.path.join(OUT, "COPY", "TBLWD" + tb["nr"] + ".cpy"), "w") as f:
        f.write(dclgen(tb))
