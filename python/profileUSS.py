import re
import sys
import yaml
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, BaseLoader

templatedir = sys.argv[1]
templatename = sys.argv[2]
envfile = sys.argv[3]

with open(envfile, 'r') as prfl:
    prfl = yaml.safe_load(prfl)

# The site's own values (host names, ports, Entra IDs) are in
# envs/<env>.local.yaml, which stays out of git; they replace those of
# envs/<env>.yaml, which has placeholders such as <host> for them.
localfile = Path(envfile).with_suffix('.local.yaml')
if localfile.is_file():
    with open(localfile, 'r') as local:
        prfl.update(yaml.safe_load(local) or {})

placeholders = sorted(k for k, v in prfl.items()
                      if isinstance(v, str) and re.search(r'<[^<>]+>', v))
if placeholders:
    sys.exit(f"{templatename}: still placeholders for {', '.join(placeholders)}; "
             f"set them in {localfile}")

environment = Environment(loader=FileSystemLoader(templatedir))
template = environment.get_template(templatename)
template2 = Environment(loader=BaseLoader).from_string(template.render(prfl))
print(template2.render(prfl))
