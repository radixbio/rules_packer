# REVIEW: is this even legit, if we can define global_substitutions?
toochain_type(name = "toolchain_type")


def _packer_toolchain_impl(ctx): # TODO this should probably be a repository rule
    toolchain_info = platform_common.ToolchainInfo(
        packerinfo = PackerInfo(
            graphics = ctx.attr.graphics,
            accelerator = ctx.attr.accelerator,
            vga = ctx.attr.vga,
            cpu = ctx.attr.cpu,
        ),
    )
    return [toolchain_info]

packer_toolchain = rule(
    implementation = _packer_toolchain_impl,
    attrs = {
        "packer_exe_name": attr.string(), # NOTE: maybe can do just the path of the packer target
        "packer_target": attr.label(),
        "accelerator": attr.string(),
        "display": attr.string(),
        "graphics": attr.string(),
        "tgt_arch": attr.string(),
    },
)
