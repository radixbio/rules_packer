#!/usr/bin/python3
import hashlib
import json
import os
from os.path import isfile
import sys
import platform
import argparse
import subprocess as sp
from typing import NamedTuple
import shutil
import logging as log
import copy

def sha256(fpath):
    BYTES_MAGIC = 65536
    sha = hashlib.sha256()
    with open(fpath, "rb") as f:
        d = f.read(BYTES_MAGIC)
        while len(d) > 0:
            sha.update(d)
            d = f.read(BYTES_MAGIC)


class Config(NamedTuple):
    """config for the python packer runner to set up packer invocation and overwrite"""
    overwrite: bool
    packerfile: str
    out_dir: str
    var_file: str
    cli_vars: dict[str, str]
    packer_path: str

    @staticmethod
    def from_json(args):
        # this try-except is to allow for parsing only the top-level object
        # inner objects are not parsed into a class
        try:
            return Config(**args)
        except TypeError:
            return args

    def cli(self):
        cmd = [self.packer_path,
               "build",
               "-force" if self.overwrite else None,
               "-var-file=" + self.var_file if self.var_file else None,
               *["-var " + '"' + k + '=' + v + '"' for k, v in self.cli_vars.items()],
               self.packerfile]
        return list(filter(lambda x: x is not None, cmd))


def parse_input_json(json_path):
    ret = None
    with open(os.path.abspath(json_path), "rb") as f:
        input = f.read()
        ret = json.loads(input, object_hook=Config.from_json)
    return ret

def deal_with_existing_out_dir(path):
    # deal with output directory
    if os.path.exists(path):
        log.debug("output dir exists, removing contents of " + path)
        f_contents = os.listdir(path)
        if len(f_contents) == 0:
            log.debug("folder empty, removing folder")
            os.rmdir(path)
        else:
            if config.overwrite:
                for root, dirs, files in os.walk(path):
                    print(root)
                    print(dirs)
                    print(files)
                    raise NotImplementedError("with files existsing is not implemented")

            else:
                raise NotImplementedError("not implemented for non-overwrite")
                pass # some clever sha thing? or just never run packer


def find_system_qemu(tgt_arch):
    # simple case, qemu_system_{tgt-arch} exists on $PATH
    qemu_search = "qemu-system-" + tgt_arch
    qemu = shutil.which(qemu_search)
    if qemu is None:
        system = platform.system().lower()
        if system == "linux":
            qemu = shutil.which(qemu_search, path = "/bin:/usr/bin:/usr/local/bin")
        elif system == "macos":
            raise NotImplementedError("TODO")
    if qemu is None:
        raise RuntimeError("cannot find " + qemu_search)
    return qemu


def invoke_packer(config, qemu_path):
    log.debug("calling: " + str(config.cli()))
    path = os.environ.get("PATH")

    if path is None:
        path = qemu_path
    else:
        path = path + ":" + qemu_path

    env = dict(copy.deepcopy(os.environ))
    env.update({"PATH": path, "PWD": os.getcwd()})
    log.debug("with PATH: " + path)
    log.debug("with ENV: " + str(env))
    proc = sp.run(' '.join(config.cli()), shell = True, env = env, cwd = os.getcwd())
    return proc

if __name__ == "__main__":
    log.basicConfig(level=log.DEBUG)
    parser = argparse.ArgumentParser()
    parser.add_argument("config")
    args = parser.parse_args()
    config = parse_input_json(args.config)
    qemu_name = find_system_qemu(platform.processor())
    qemu_path = os.path.dirname(qemu_name)
    deal_with_existing_out_dir(config.out_dir)
    packer = invoke_packer(config, qemu_path)
    sys.exit(packer.returncode)
