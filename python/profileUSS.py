# Renders one DDL or JCL member with the values of an environment, for
# DEPLOY.zmake (through profileUSS.sh):
#   python python/profileUSS.py <template dir> <template name> <env file>
# The values come from envConfig.py: the env file, its .local.yaml on top.
import sys

from jinja2 import BaseLoader, Environment, FileSystemLoader

import envConfig

templatedir = sys.argv[1]
templatename = sys.argv[2]
envfile = sys.argv[3]

prfl = envConfig.loadFile(envfile)

environment = Environment(loader=FileSystemLoader(templatedir))
template = environment.get_template(templatename)
template2 = Environment(loader=BaseLoader).from_string(template.render(prfl))
print(template2.render(prfl))
