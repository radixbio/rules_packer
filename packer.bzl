load("@com_github_rules_packer_config//:config.bzl", "PACKER_VERSION", "PACKER_SHAS", "PACKER_OS", "PACKER_ARCH", "PACKER_BIN_NAME")

#load("@bazel_tools//tools/build_defs/pkg:pkg.bzl", "pkg_tar")
#
#def assemble_packer(
#        name,
#        config,
#        files = {}):
#    """Assemble files for HashiCorp Packer deployment
#
#    Args:
#        name: A unique name for this target.
#        config: Packer JSON/HCL config
#        files: Files to include into deployment
#    """
#
#    exn = ".".join(config.split(".")[1:])
#    print(exn)
#    _files = {
#        config: "config." + exn,
#    }
#    for k, v in files.items():
#        _files[k] = "files/" + v
#    pkg_tar(
#        name = name,
#        extension = "packer.tar",
#        files = _files,
#    )
#
def _packer_impl(ctx):
    # hostnames can't have underscores, so neither can the rule name
    if ctx.attr.name != ctx.attr.name.replace("_", "-"):
        fail("hostnames cannot contain underscores, please rename your rule name")

    # packer binaries
    packers = ctx.files._packer

    # python script that will be templated
    deployment_script = ctx.actions.declare_file("{}_deploy_packer.py".format(ctx.attr.name))

    # for packer
    additional_files = [y for x in ctx.attr.files for y in x.files.to_list()]

    # packer scripts arg
    scripts = [y for x in ctx.attr.scripts for y in x.files.to_list()]

    # qcow / iso boot media
    bootmedia_F = ctx.attr.bootmedia.files.to_list()
    bootmedia = [x.path for x in bootmedia_F]

    # optional external media
    auxmedia_F = [] if ctx.attr.auxmedia == None else ctx.attr.auxmedia.files.to_list()
    auxmedia = [x.path for x in auxmedia_F]

    # headless install kickstart files
    kickstarts_F = [y for x in ctx.attr.kickstart for y in x.files.to_list()]
    kickstarts = [x.path for x in kickstarts_F]

    # and generate the output file in a directory called out + the file is named the VM name
    output_file = ctx.actions.declare_file(ctx.attr.name)

    # pass these into a python file that will run packer
    ctx.actions.expand_template(
        template = ctx.file._deployment_script_template,
        output = deployment_script,
        substitutions = {
            "{packer_osx_binary}": packers[0].path,
            "{packer_linux_binary}": packers[1].path,
            "{packer_windows_binary}": packers[2].path,
            "{builders}": str(ctx.attr.builders),
            "{provisioners}": str(ctx.attr.provisioners),
            "{name}": ctx.attr.name,
            "{additional_files}": str([x.path for x in additional_files]),
            "{scripts}": str([x.path for x in scripts]),
            "{bootmedia}": str(bootmedia),
            "{auxmedia}": str(auxmedia),
            "{kickstart}": str(kickstarts),
            "{username}": str(ctx.attr.username),
            "{password}": str(ctx.attr.username),
            "{memory}": str(ctx.attr.memory),
            "{graphics}": str(ctx.attr.graphics),
            "{cpu}": str(ctx.attr.cpu),
            "{smp}": str(ctx.attr.smp),
            "{output_file}": str(output_file.path),
            "{debug}": str(ctx.attr.debug),
        },
        is_executable = True,
    )

    # actually run the python script
    ctx.actions.run(
        inputs = additional_files + scripts + bootmedia_F + auxmedia_F + kickstarts_F + packers,
        outputs = [output_file],
        executable = deployment_script,
        mnemonic = "PackerBuild",
        use_default_shell_env = True,  # NOTE required unless we want to build QEMU from source per-platform (sounds annoying af)
    )

    return DefaultInfo(
        executable = deployment_script,
        runfiles = ctx.runfiles(files = additional_files + scripts + ctx.files._packer + bootmedia_F + auxmedia_F),
        files = depset([output_file]),
    )

packer = rule(
    attrs = {
        #        "config_file": attr.label(
        #            mandatory = True,
        #        ),
        "overwrite": attr.bool(
            mandatory = False,
        ),
        "tars": attr.label_list(
        ),
        "scripts": attr.label_list(
            allow_files = True,
        ),
        "builders": attr.string_list(),
        "provisioners": attr.string_list(),
        "files": attr.label_list(
            allow_files = True,
        ),
        "substitutions": attr.string_dict(),
        "bootmedia": attr.label(),
        "auxmedia": attr.label(),
        "bootchecksum": attr.string(),
        "http_dir": attr.label_list(),
        "graphics": attr.string(
            default = "gtk",  # not sure if this is going to need to be host execution platform specific
        ),
        "memory": attr.int(
            default = 1024,
        ),
        #        "hostname": attr.string(
        #
        #        ),
        "username": attr.string(
            default = "vagrant",
        ),
        "password": attr.string(
            default = "vagrant",
        ),
        "kickstart": attr.label_list(
            allow_files = True,
        ),
        "cpu": attr.string(
            default = "host",
        ),
        "smp": attr.string(
            default = "cpus=1",
        ),
        "debug": attr.bool(
            default = False,
        ),
        "_deployment_script_template": attr.label(
            allow_single_file = True,
            default = "//containers/packer/templates:my_deploy_packer.py",
        ),
        "_packer": attr.label(
            allow_single_file = True,
            default = "@packer_osx//:" + PACKER_BIN_NAME
        ),
    },
    executable = True,
    implementation = _packer_impl,
)


