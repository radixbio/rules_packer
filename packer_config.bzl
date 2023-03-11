_LUT = {
    "macosx" : "darwin",
    "aarch64": "arm64",
    "linux": "linux",
    "windows": "windows",
    "x86_64": "amd64",
    "i386": "386",       # Untested
    "arm": "arm",
    "ppc64": "ppc64le",   # Untested
    "freebsd": "freebsd", # Untested
    "netbsd": "netbsd",   # Untested
    "openbsd": "openbsd", # Untested
    "solaris": "solaris"
}


_PKR_URL = "https://releases.hashicorp.com/packer/{version}/packer_{version}_{os}_{arch}.zip"

def _java_prop_to_hashicorp(str):
    return _LUT[str]

def _hashicorp_to_java_prop(str):
    return {v: k for k, v in _LUT.items()}[str]

def _packer_configure_impl(repository_ctx):
    packer_version = repository_ctx.attr.packer_version
    repository_ctx.download(
        url = "https://releases.hashicorp.com/packer/{version}/packer_{version}_SHA256SUMS".format(version = packer_version),
        output = "packer_{version}_shas.txt".format(version = packer_version)
    )
    shas = repository_ctx.read(
        "packer_{version}_shas.txt".format(version = packer_version)
    )
    shas = {x[66 + len("packer_{version}_".format(version = packer_version)):-4]:x[:64] for x in shas.split("\n")}
    shas = [{k.split("_")[0]: {k.split("_")[1]: v}} for k, v in shas.items() if k.find("_") != -1]
    os_arch_sha = {}
    for d in shas:
        (os, inner) = d.popitem()
        (arch, sha) = inner.popitem()
        url = _PKR_URL.format(
            version = packer_version,
            os = os,
            arch = arch
        )
        existing_inner = os_arch_sha.get(_hashicorp_to_java_prop(os), {_hashicorp_to_java_prop(arch): (url, sha)})
        existing_inner.update([(_hashicorp_to_java_prop(arch), (url, sha))])
        os_arch_sha.update([(_hashicorp_to_java_prop(os), existing_inner)])

    packer_bin_name = None
    if repository_ctx.os.name == "windows":
        packer_bin_name = "packer.exe"
    else:
        packer_bin_name = "packer"

    config_file_content = """
    PACKER_VERSION="{packer_version}"
    PACKER_OS="{os}"
    PACKER_ARCH="{arch}"
    PACKER_SHAS={packer_shas}
    PACKER_BIN_NAME="{packer_bin_name}"
    PACKER_GLOBAL_SUBS={global_substitutions}
    PACKER_DEBUG={debug}
    """.format(
        packer_version = packer_version,
        packer_shas = str(os_arch_sha),
        os = repository_ctx.os.name,
        arch = repository_ctx.os.arch,
        packer_bin_name = packer_bin_name,
        global_substitutions = repository_ctx.attr.global_substitutions,
        debug = repository_ctx.attr.debug
    ).replace(" ", "")

    repository_ctx.file("config.bzl", config_file_content)
    repository_ctx.file("BUILD")

_packer_configure = repository_rule(
    implementation = _packer_configure_impl,
    attrs = {
        "packer_version": attr.string(
            mandatory = True
        ),
        "global_substitutions": attr.string_dict(),
        "debug": attr.bool(
            default = False
        )
    }
)
def packer_configure(packer_version, global_substitutions, debug):
    _packer_configure(
        name = "com_github_rules_packer_config",
        packer_version = packer_version,
        global_substitutions = global_substitutions,
        debug = debug
    )
