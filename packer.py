#!/usr/bin/env python3
import os
import sys
import tempfile
import tarfile
import platform
import subprocess as sp
import shutil
import json
from string import Template
import hashlib
BYTES_MAGIC = 65536
def sha256(fpath):
    sha = hashlib.sha256()
    with open(fpath, "rb") as f:
        d = f.read(BYTES_MAGIC)
        while len(d) > 0:
            sha.update(d)
            d = f.read(BYTES_MAGIC)
    return sha.hexdigest()
PACKER_BINARIES = {
    "Darwin": os.path.abspath("{packer_osx_binary}"),
    "Linux": os.path.abspath("{packer_linux_binary}"),
    "Windows": os.path.abspath("{packer_windows_binary}"),
}

SCRIPTS = [os.path.abspath(x) for x in {scripts}]
FILES = str([os.path.abspath(x) for x in {additional_files}]).replace("'", '"')
BOOTFILE = str([os.path.abspath(x) for x in {bootmedia}][0])
BOOTMEDIA = "file://" + BOOTFILE
BOOTCHECKSUM = sha256(BOOTFILE)
AUXMEDIA = str(next(iter([os.path.abspath(x) for x in {auxmedia}]), ""))
PROVISIONERS = [
    Template(x).substitute({"scripts": str(SCRIPTS).replace("'", '"')})
    for x in {provisioners}
]
PROVISIONERS = [json.loads(x) for x in PROVISIONERS]
HTTP_DIR = os.getcwd()
print(HTTP_DIR)
USERNAME = "{username}"
PASSWORD = "{password}"
MEMORY = "{memory}"
GRAPHICS = "{graphics}"
TARGET_NAME = "{name}"
CPU = "{cpu}"
SMP = "{smp}"
FLOPPY = str({kickstart}).replace("'", '"')
OUTPUT_FILE = "{output_file}"
BUILDERS = [
    # TODO change this to safe substitute
    Template(x).substitute(
        {
            "iso_url": BOOTMEDIA,
            "iso_checksum": BOOTCHECKSUM,
            "aux_iso_url": AUXMEDIA,
            "http_dir": HTTP_DIR,
            "username": USERNAME,
            "password": PASSWORD,
            "name": TARGET_NAME,
            "memory": MEMORY,
            "graphics": GRAPHICS,
            "cpu": CPU,
            "smp": SMP,
            "kickstart": FLOPPY,
            "files": FILES,
        }
    )
    for x in {builders}
]
BUILDERS = [json.loads(x) for x in BUILDERS]
PACKER_JSON = {"builders": BUILDERS, "provisioners": PROVISIONERS}
system = platform.system()
if system not in PACKER_BINARIES:
    raise ValueError("Packer does not have binary for {}".format(system))
# TARGET_TAR_LOCATION = "{name}"
with open("config.json", "w+") as f:
    f.write(json.dumps(PACKER_JSON))
# with tarfile.open(TARGET_TAR_LOCATION, 'r') as target_tar:
#    target_tar.extractall(target_temp_dir)
# sp.check_call([PACKER_BINARIES[system], 'init', 'config.json'], cwd = target_temp_dir)
args = [
    PACKER_BINARIES[system],
    "build",
]
if "{force}":
    args.append("-force")
args.append("config.json")
sp.check_call(args)

# Make the directory for the output file
os.makedirs(os.path.dirname("out/" + TARGET_NAME), exist_ok=True)
os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
shutil.move("out/" + TARGET_NAME, OUTPUT_FILE)
