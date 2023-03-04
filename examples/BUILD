load("//:packer.bzl", "packer2")

exports_files([
    "ubuntu2.json",
    "ubuntu1804.json"
])


packer2(
    name = "ubuntu1804",
    overwrite = False,
    packerfile = ":ubuntu2.json",
    var_file = ":ubuntu1804.json"
)
