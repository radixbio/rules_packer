load("//:packer.bzl", "packer_qemu")
load("@com_github_rules_packer_config//:config.bzl", "PACKER_DEBUG")

exports_files([
    "ubuntu2.json",
    "ubuntu1804.json"
])


packer_qemu(
    name = "ubuntu1804",
    overwrite = True,
    packerfile = ":ubuntu2.json",
    var_file = ":ubuntu1804.json",
    input_img = "@ubuntu18046_x64//file",
    deps = glob(["scripts/**"]) + ["http/preseed.cfg"],
    substitutions = {
        "{preseed}": "$(location http/preseed.cfg)",
        "{scripts}": ",".join(["$(location scripts/" + x + ")" for x in ["vagrant.sh", "sshd.sh", "update.sh", "packages.sh", "cleanup.sh"]]),
        "{output}": "$(location output)",
    },
    vars = {
        "foo": "bar"
    },
    debug = True
)


packer_qemu(
    name = "ubuntu1804_w_update",
    overwrite = True,
    packerfile = ":ubuntu_update.json",
    var_file = ":ubuntu_update.var.json",
    input_img = ":ubuntu1804",
    sha256_var_name = "iso_checksum",
    substitutions = {
        "{output}": "$(location output)",
    }
)
