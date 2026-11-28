# Submits the zmake build of this repository (ZMAKE/BUILD.zmake).
#
#   python python/build.py [hlq] [target] [--env <env>] [--dry-run]
#
# target: a zmake target, default BUILD_ALL; setenv's build function passes
# $(loadlib)(<member>) to build one program. hlq: the build libraries'
# prefix, default BUILDHLQ of the environment.
# The site's values (LWZMHLQ, BUILDHLQ, VERSION, CICSHLQ, DB2HLQ, job
# classes) come from envs/<env>.yaml and envs/<env>.local.yaml
# (envConfig.py); the environment is --env, else $LWD_ENV, else t01.
import argparse
import os
import subprocess
import sys
import tempfile

from jinja2 import Template
from pathlib import Path

import envConfig

template_src = '''//BUILD    JOB 'BUILD',CLASS={{ jobclass }},MSGCLASS={{ msgclass }},NOTIFY=&SYSUID
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
version := {{ version }}
hlq := {{ hlq }}.{{ version }}
gitdir := {{ gitdir }}
cicshlq := {{ cicshlq }}
db2hlq := {{ db2hlq }}

{{ zmake_file }}'''

parser = argparse.ArgumentParser(description="Submit the zmake build")
parser.add_argument("args", nargs="*", metavar="[hlq] [target]",
                    help="target (default BUILD_ALL), or hlq and target")
parser.add_argument("-e", "--env", default=envConfig.DEFAULT_ENV,
                    help="environment whose values to use (default: %(default)s)")
parser.add_argument("-n", "--dry-run", action="store_true",
                    help="print the JCL instead of submitting it")
args = parser.parse_args()

if len(args.args) > 2:
    parser.error("give at most hlq and target")

values = envConfig.load(args.env)
lwzmhlq, buildhlq, version, cicshlq, db2hlq, jobclass, msgclass = envConfig.require(
    values, "LWZMHLQ", "BUILDHLQ", "VERSION", "CICSHLQ", "DB2HLQ",
    "BUILDJOBCLASS", "BUILDMSGCLASS")

with open("ZMAKE/BUILD.zmake", "r") as file:
    zmake_file = file.read()

data = {
    "target": "BUILD_ALL",
    "homedir": Path.home(),
    "hlq": buildhlq,
    "version": version,
    "gitdir": os.getcwd(),
    "cicshlq": cicshlq,
    "db2hlq": db2hlq,
    "lwzmhlq": lwzmhlq,
    "jobclass": jobclass,
    "msgclass": msgclass,
    "zmake_file": zmake_file
}

if len(args.args) == 2:
    data["hlq"], data["target"] = args.args
elif len(args.args) == 1:
    data["target"] = args.args[0]

jcl = Template(template_src).render(data)

if args.dry_run:
    print(jcl)
    sys.exit(0)

with tempfile.NamedTemporaryFile("w", suffix=".jcl") as temp:
    temp.write(jcl)
    temp.flush()
    sys.exit(subprocess.call(["submit", temp.name]))
