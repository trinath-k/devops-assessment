#!/usr/bin/env python
import subprocess
import json
publicip = subprocess.check_output(["curl -s ifconfig.me"], shell=True).decode("utf-8")
data = {"publicip": "{}/32".format(publicip)}
jsondata = json.dumps(data)
print(jsondata)

