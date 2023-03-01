#!/usr/bin/env python3
#
#
#
import hashlib
from io import StringIO
import json
import os
import platform

def sha256(fpath):
    BYTES_MAGIC = 65536
    sha = hashlib.sha256()
    with open(fpath, "rb") as f:
        d = f.read(BYTES_MAGIC)
        while len(d) > 0:
            sha.update(d)
            d = f.read(BYTES_MAGIC)


def packer_path():
    bin = {
        "Darwin": {
            "x86_64": os.path.abspath("{packer_osx_arm64_binary}"),
            "arm64": os.path.abspath("{packer_osx_arm54_binary}")
        },
        "Linux": {
            "x86_64": os.path.abspath("packer_linux_amd64_binary"),
        },
        "Windows": {
            "x86_64": os.path.abspath("packer_windows_amd64_binary")
        }
    }
    return bin[platform.system()][platform.architecture()[0]]

def parse_input_json(json_path):
    ret = None
    with open(os.path.abspath(json_path), "rb") as f:
        ret = json.load(f)
    return ret
