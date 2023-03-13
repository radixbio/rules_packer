toochain_type(name = "toolchain_type")


def _packer_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        packercinfo = PackercInfo(
            compiler_path = ctx.attr.compiler_path,
            system_lib = ctx.attr.system_lib,
            arch_flags = ctx.attr.arch_flags,
        ),
    )
    return [toolchain_info]

packer_toolchain = rule(
    implementation = _packer_toolchain_impl,
    attrs = {
        "packer_exe_name": attr.string(),
        "discovered_accelerators": attr.string_list(),
        "display": attr.string(),
        "graphics": attr.string(),
        "host_arch": attr.string(),
        "tgt_arch": attr.string(),
        "qemu": attr.label(),
    },
)
