import yaml

from jinja2 import Template
from pathlib import Path
import sys
import os
import tempfile

template_src = '''//DEPLOY   JOB 'DEPLOY',CLASS=A,MSGCLASS=A,NOTIFY=&SYSUID
//*
//      EXPORT SYMLIST=*
//         SET LWZMHLQ=YINSYS.LWZM020
//      JCLLIB ORDER=(&LWZMHLQ..JCL)
//*
//ZMAKE   EXEC PROC=ISPFMAKE,
//             LWZMHLQ=&LWZMHLQ,
//             MAKEPARM='-t {{ target }}',
//             EXECLIB=&LWZMHLQ..EXEC,
//             DYNAMNBR.ZMAKE=100
//ZMAKE.LWZMINP DD *,SYMBOLS=EXECSYS
.USSHOME = {{ homedir }}
env     := {{ env }}
envl    := {{ envl }}
srchlq  := {{ srchlq }}.{{ version }}
tgthlq  := {{ tgthlq }}
lwddb   := {{ lwddb }}
gitdir  := {{ gitdir }}
tickdir := {{ tickdir }}

{{ zmake_file }}'''

jcl_template = Template(template_src)

with open("ZMAKE/DEPLOY.zmake", "r") as file:
    zmake_file = file.read()

data = {
    "target": "DEPLOY_ALL",
    "homedir": Path.home(),
    "srchlq": f"{os.getlogin()}.LWD",
    "version": "V1",
    "env": "T01",
    "envl": "t01",
    "gitdir": os.getcwd(),
    "zmake_file": zmake_file
}

if len(sys.argv) > 1:
    data["target"] = sys.argv[1]
if len(sys.argv) > 2:
    data["env"] = sys.argv[2].upper()
    data["envl"] = sys.argv[2].lower()
data["tgthlq"] = f"YINCIC.CPSM.{data['env']}.LWD"
data["lwddb"] = data["env"]

# Where the scheduled tick's code goes (TICKDIR in envs/<env>.yaml, or in
# envs/<env>.local.yaml, the site's own values, which stays out of git)
with open(f"envs/{data['envl']}.yaml", "r") as envfile:
    envvalues = yaml.safe_load(envfile)
if os.path.isfile(f"envs/{data['envl']}.local.yaml"):
    with open(f"envs/{data['envl']}.local.yaml", "r") as envfile:
        envvalues.update(yaml.safe_load(envfile) or {})
data["tickdir"] = envvalues["TICKDIR"]

jcl = jcl_template.render(data)

temp = tempfile.NamedTemporaryFile()

with open(temp.name, "w") as file:
    file.write(jcl)

os.system(f"submit {temp.name}")
