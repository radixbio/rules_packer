local_repository(
    name = "com_github_rules_packer",
    path = "."
)

load("@com_github_rules_packer//:packer_config.bzl", "packer_configure")

packer_configure(
    packer_version = "1.8.6",
    global_substitutions = {
        '"{$foo}"': "bar"
    },
    debug = False
)


load("@com_github_rules_packer//:packer_dependencies.bzl", "packer_dependencies")

packer_dependencies()

load("@aspect_bazel_lib//lib:repositories.bzl", "aspect_bazel_lib_dependencies")

aspect_bazel_lib_dependencies()
