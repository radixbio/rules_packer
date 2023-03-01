load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@com_github_rules_packer_config//:config.bzl", "PACKER_VERSION", "PACKER_SHAS", "PACKER_OS", "PACKER_ARCH", "PACKER_BIN_NAME")

def packer_dependencies():
    packer_exports = 'exports_files(["' + PACKER_BIN_NAME + '"])'

    maybe(
        http_archive,
        name = "packer",
        url = "https://releases.hashicorp.com/packer/{version}/packer_{version}_{os}_{arch}.zip".format(version = PACKER_VERSION, os = PACKER_OS, arch = PACKER_ARCH),
        sha256 = PACKER_SHAS[PACKER_OS][PACKER_ARCH],
        build_file_content = packer_exports
     )
