# Submits the zmake deploy of this repository (ZMAKE/DEPLOY.zmake) to one
# environment: renders the DDL and JCL, copies the load modules, DBRMs and
# REXX, binds the packages and copies the tick's code to TICKDIR.
#
#   python python/deploy.py [target] [env] [--dry-run]
#
# target: a zmake target, default DEPLOY_ALL (DEPLOY_DDL: only DDL and JCL,
# DEPLOY_TICK: only the tick's code).
# env: t01, t03, ...; default $LWD_ENV, else t01.
# The site's values (TGTHLQ, BUILDHLQ, VERSION, DB2SSID, PKGCOLLID, SQLID,
# SCHEMA, TICKDIR, LWZMHLQ, job classes) come from envs/<env>.yaml and
# envs/<env>.local.yaml (envConfig.py).
import argparse
import os
import subprocess
import sys
import tempfile

from jinja2 import Template
from pathlib import Path

import envConfig

template_src = '''//DEPLOY   JOB 'DEPLOY',CLASS={{ jobclass }},MSGCLASS={{ msgclass }},NOTIFY=&SYSUID
//*
//      EXPORT SYMLIST=*
//         SET LWZMHLQ={{ lwzmhlq }}
//      JCLLIB ORDER=(&LWZMHLQ..JCL)
//*
//ZMAKE   EXEC PROC=ISPFMAKE,
//             LWZMHLQ=&LWZMHLQ,
//             MAKEPARM='-t {{ target }}',
//             EXECLIB=&LWZMHLQ..EXEC,
//             DYNAMNBR.ZMAKE=100
//ZMAKE.LWZMINP DD *,SYMBOLS=EXECSYS
.USSHOME = {{ homedir }}
env       := {{ env }}
envl      := {{ envl }}
srchlq    := {{ srchlq }}.{{ version }}
tgthlq    := {{ tgthlq }}
db2ssid   := {{ db2ssid }}
pkgcollid := {{ pkgcollid }}
sqlid     := {{ sqlid }}
schema    := {{ schema }}
gitdir    := {{ gitdir }}
tickdir   := {{ tickdir }}

{{ zmake_file }}'''

parser = argparse.ArgumentParser(description="Submit the zmake deploy to an environment")
parser.add_argument("target", nargs="?", default="DEPLOY_ALL",
                    help="zmake target (default: %(default)s)")
parser.add_argument("env", nargs="?", default=envConfig.DEFAULT_ENV,
                    help="environment (default: %(default)s)")
parser.add_argument("-n", "--dry-run", action="store_true",
                    help="print the JCL instead of submitting it")
args = parser.parse_args()

values = envConfig.load(args.env)
(env, buildhlq, version, tgthlq, db2ssid, pkgcollid, sqlid, schema, tickdir,
 lwzmhlq, jobclass, msgclass) = envConfig.require(
    values, "ENV", "BUILDHLQ", "VERSION", "TGTHLQ", "DB2SSID", "PKGCOLLID",
    "SQLID", "SCHEMA", "TICKDIR", "LWZMHLQ", "BUILDJOBCLASS", "BUILDMSGCLASS")

with open("ZMAKE/DEPLOY.zmake", "r") as file:
    zmake_file = file.read()

data = {
    "target": args.target,
    "homedir": Path.home(),
    "env": env.upper(),
    "envl": args.env.lower(),
    "srchlq": buildhlq,
    "version": version,
    "tgthlq": tgthlq,
    "db2ssid": db2ssid,
    "pkgcollid": pkgcollid,
    "sqlid": sqlid,
    "schema": schema,
    "tickdir": tickdir,
    "lwzmhlq": lwzmhlq,
    "jobclass": jobclass,
    "msgclass": msgclass,
    "gitdir": os.getcwd(),
    "zmake_file": zmake_file
}

jcl = Template(template_src).render(data)

if args.dry_run:
    print(jcl)
    sys.exit(0)

with tempfile.NamedTemporaryFile("w", suffix=".jcl") as temp:
    temp.write(jcl)
    temp.flush()
    sys.exit(subprocess.call(["submit", temp.name]))
