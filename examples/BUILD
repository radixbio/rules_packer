load("//:packer.bzl", "packer2")

exports_files([
    "ubuntu2.json",
    "ubuntu1804.json"
])


packer2(
    name = "ubuntu1804",
    overwrite = True,
    packerfile = ":ubuntu2.json",
    var_file = ":ubuntu1804.json",
    deps = glob(["scripts/**"]) + ["http/preseed.cfg"]
)
