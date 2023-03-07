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

    maybe(
        http_archive,
        name = "aspect_bazel_lib",
        sha256 = "2518c757715d4f5fc7cc7e0a68742dd1155eaafc78fb9196b8a18e13a738cea2",
        strip_prefix = "bazel-lib-1.28.0",
        url = "https://github.com/aspect-build/bazel-lib/releases/download/v1.28.0/bazel-lib-v1.28.0.tar.gz",
    )
