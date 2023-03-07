load("@com_github_rules_packer_config//:config.bzl", "PACKER_VERSION", "PACKER_SHAS", "PACKER_OS", "PACKER_ARCH", "PACKER_BIN_NAME", "PACKER_GLOBAL_SUBS", "PACKER_DEBUG")
load("@aspect_bazel_lib//lib:expand_make_vars.bzl", "expand_locations")
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


def _packer2_impl(ctx):
    print("overwrite: " + str(ctx.attr.overwrite))
    print("packerfile: " + str(ctx.attr.packerfile))
    print("var_file: " + str(ctx.attr.var_file))
    print("packer: " + str(dir(ctx.file.packerfile)))
    print("subst: " + str(PACKER_GLOBAL_SUBS))

    out = ctx.actions.declare_directory("output")

    substitutions = {}
    substitutions.update(PACKER_GLOBAL_SUBS)
    subst_items = {k: v for k, v in ctx.attr.substitutions.items()}
    if subst_items.get("{output}") == "$(location output)":
        subst_items.update({"{output}": out.path})
    substitutions.update({expand_locations(ctx, k, ctx.attr.deps): expand_locations(ctx, v, ctx.attr.deps) for k, v in subst_items.items()})

    print(substitutions)

    name = ctx.attr.name
    packerfile = ctx.actions.declare_file(name + ".pkr")
    var_file = None

    args = []
    env = {k: v for k, v in ctx.args.env.items()}
    env.update({expand_locations(ctx, k, ctx.attr.deps): expand_locations(ctx, v, ctx.attr.deps) for k, v in env.items()})

#    args.append(ctx.file._packer.path)
    args.append("build")

    if ctx.attr.overwrite:
        args.append("-force")

    if ctx.attr.debug:
        env.update({"PACKER_LOG": "1"})
        args.append("-debug")

    if ctx.attr.var_file:
        var_file = ctx.actions.declare_file(name + ".var")
        ctx.actions.expand_template(
            template = ctx.file.var_file,
            output = var_file,
            substitutions = substitutions
        )
        args.append("-var-file=" + var_file.path)



    ctx.actions.expand_template(
        template = ctx.file.packerfile,
        output = packerfile,
        substitutions = substitutions
    )
    args.append(packerfile.path)

    print(args)

    run = ctx.actions.declare_file("run")
    ctx.actions.write(output = run, content = "PACKER_LOG=1 " + ctx.file._packer.path + " " + " ".join(args), is_executable=True)

#    wd = ctx.build_file_path[:-6] # /BUILD
#    print(ctx.files.deps)
#    print(ctx.files.deps[0].path)
#
#    res_cp = " && ".join([ "mkdir -p `dirname " + ctx.bin_dir.path + "/" + x.path + "` && " + "cp -r " + x.path + " " + ctx.bin_dir.path + "/" + x.path for x in ctx.files.deps])
#    print(res_cp)
    ctx.actions.run(
        #arguments = [args],
        #executable = ctx.file._packer,
        #executable = "tree",
        #executable = [ctx.file._packer.path + " " + " ".join(args)],
        executable = run,
        env = env,
        inputs = [x for x in [packerfile, var_file] if x != None] + ctx.files.deps, # Look, i know it's stupid
        outputs = [out],
        use_default_shell_env = True,
        tools = [ctx.file._packer]
    )



    return [DefaultInfo(files=depset([out]))]

packer2 = rule(
    implementation = _packer2_impl,
    attrs = {
        "overwrite": attr.bool(
            default = False
        ),
        "packerfile": attr.label(
            allow_single_file = True,
            mandatory = True
        ),
        "var_file": attr.label(
            allow_single_file = True,
        ),
        "substitutions": attr.string_dict(), # NOTE: Substitutes in the templates
        "vars": attr.string_dict(), # NOTE: passed as CLI args
        "env": attr.string_dict(), # NOTE: passed to the packer command
        "deps": attr.label_list(
            allow_files = True
        ),
        "_deployment_script": attr.label(
            allow_single_file = True,
            default = "//:packer2.py"
        ),
        "debug": attr.bool(
            default = PACKER_DEBUG
        ),
        "_packer": attr.label(
            allow_single_file = True,
            default = "@packer//:" + PACKER_BIN_NAME
        )
    }
)
