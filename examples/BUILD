load("//:packer.bzl", "packer2")
load("@com_github_rules_packer_config//:config.bzl", "PACKER_DEBUG")

exports_files([
    "ubuntu2.json",
    "ubuntu1804.json"
])


packer2(
    name = "ubuntu1804",
    overwrite = True,
    packerfile = ":ubuntu2.json",
    var_file = ":ubuntu1804.json",
    deps = glob(["scripts/**"]) + ["http/preseed.cfg", "@ubuntu18046_x64//file:file"],
    substitutions = {
        "{preseed}": "$(location http/preseed.cfg)",
        "{headless}": "false" if PACKER_DEBUG else "true",
        "{scripts}": ",".join(["$(location scripts/" + x + ")" for x in ["vagrant.sh", "sshd.sh", "update.sh", "packages.sh", "cleanup.sh"]]),
        "{output}": "$(location output)",
        "{http_dir}": ".",
        "{iso}": "file://{{env `PWD`}}/$(location @ubuntu18046_x64//file:file)"
    }
)
