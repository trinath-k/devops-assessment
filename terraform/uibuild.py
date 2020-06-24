#!/usr/bin/env python
import subprocess
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-i","--ip", help="public ip address of nginx server", required=True)
args = parser.parse_args()
nginx_ip = args.ip
subprocess.check_output(["rm -rf artifacts/helloworld"], shell=True)
subprocess.check_output(["unzip artifacts/helloworld.zip -d artifacts/"], shell=True)

files = ["artifacts/helloworld/main.js","artifacts/helloworld/main.js.map"]

def replace_ip(file,ip):
    with open(file,"r") as mainjs:
        newText = mainjs.read().replace('nginxserver', '{}'.format(ip))

    with open(file, "w") as f:
        f.write(newText)


for file in files:
    replace_ip(file,nginx_ip)

subprocess.check_output(["cd artifacts && zip -r frontend.zip helloworld && mv frontend.zip ../playbooks/"], shell=True)