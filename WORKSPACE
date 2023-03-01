local_repository(
    name = "com_github_rules_packer",
    path = "."
)

load("@com_github_rules_packer//:packer_config.bzl", "packer_configure")

packer_configure(
    packer_version = "1.8.6"
)


load("@com_github_rules_packer//:packer_dependencies.bzl", "packer_dependencies")

packer_dependencies()
