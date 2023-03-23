load("@com_github_rules_packer_config//:config.bzl", "PACKER_VERSION", "PACKER_SHAS", "PACKER_OS", "PACKER_ARCH", "PACKER_BIN_NAME", "PACKER_GLOBAL_SUBS", "PACKER_DEBUG")
load("@aspect_bazel_lib//lib:expand_make_vars.bzl", "expand_locations")
load("@bazel_skylib//lib:paths.bzl", "paths")

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



def _img_path_subst(fmtstring, replace, replace_val):
    if fmtstring.find(replace) != -1:
        fst = fmtstring[:fmtstring.find(replace)]
        snd = fmtstring[fmtstring.find(replace) + len(replace):]
        return fst + replace_val + snd
    else:
        return fmtstring

def _subst(ctx, in_dict, deps, input_img, input_img_key, add_subst = False):
    cp = {k: v for k, v in in_dict.items()}
    out_dict = []

    path = input_img.files.to_list()[0]
    if path.is_directory:
        path = paths.join(path.path, path.basename)
    else:
        path = path.path

    img_path = _img_path_subst(ctx.attr.input_img_fmtstring, "{input_img}", path)

    for k, v in cp.items():
        k_subs = expand_locations(ctx, k, deps)
        v_subs = _img_path_subst(expand_locations(ctx, v, deps + [input_img]), input_img_key, img_path)
        out_dict.append((k_subs, v_subs))
    out_dict = dict(out_dict)
    if add_subst:
        out_dict.update({input_img_key: img_path})
    return out_dict

def _packer_qemu_impl(ctx):
    # Declare our output directory (this may not be a thing for all builders, but it is for QEMU)
    out = ctx.actions.declare_directory(ctx.attr.name)
    if len(ctx.attr.input_img.files.to_list()) != 1:
        fail("input_img has multiple files: " + ctx.attr.input_img.files.to_list())

    # this may be a file (http_file) or a directory (deps on another packer_qemu rule)
    path = ctx.attr.input_img.files.to_list()[0]
    if path.is_directory:
        path = paths.join(path.path, path.basename)
    else:
        path = path.path

    img_path = _img_path_subst(ctx.attr.input_img_fmtstring, "{input_img}", path)

    # declare our substitutions, merge with the global map, and splice in output / $(locations)
    subst_items = {k: v for k, v in ctx.attr.substitutions.items()}
    subst_items.update(PACKER_GLOBAL_SUBS)
    if subst_items.get("{output}") == "$(location output)":
        subst_items.update({"{output}": out.path})
    substitutions = _subst(ctx, subst_items, ctx.attr.deps, ctx.attr.input_img, ctx.attr.input_img_subs_key, True)

    # declare our environent, splice in output / $(locations)
    env_items = {k: v for k, v in ctx.attr.env.items()}
    if env_items.get("{output}") == "$(location output)":
        env_items.update({"{output}": out.path})
    env = _subst(ctx, env_items, ctx.attr.deps, ctx.attr.input_img, ctx.attr.input_img_subs_key)

    # packer has a debug thing ...
    if ctx.attr.debug:
        env.update({"PACKER_LOG": "1"})

    # and support for var files with $(location)
    var_file = None
    if ctx.attr.var_file:
        var_file = ctx.actions.declare_file(ctx.attr.name + ".var")
        ctx.actions.expand_template(
            template = ctx.file.var_file,
            output = var_file,
            substitutions = substitutions
        )

    # pack the vars command line arguments, substituting $(location) and {input_img}
    cli_vars = _subst(ctx, ctx.attr.vars, ctx.attr.deps, ctx.attr.input_img, ctx.attr.input_img_subs_key)

    # as well as the actual packerfile with $(location)
    packerfile = ctx.actions.declare_file(ctx.attr.name + ".pkr")
    ctx.actions.expand_template(
        template = ctx.file.packerfile,
        output = packerfile,
        substitutions = substitutions
    )

    # NOTE this is done due to weird bazel args quoting when the input has an = or > in it
    run = ctx.actions.declare_file("run-" + ctx.attr.name)

    pyscript_content = """
      "overwrite": {overwrite},
      "packerfile": "{packerfile}",
      "out_dir": "{out_dir}",
      "var_file": "{var_file}",
      "cli_vars": {cli_vars},
      "packer_path": "{packer_path}",
      "sha256_var_name": "{sha256_var_name}",
      "iso_img_loc": "{iso_img_loc}"
    """.format(
        overwrite = str(ctx.attr.overwrite).lower(),
        packerfile = packerfile.path,
        out_dir = out.path,
        cli_vars = cli_vars,
        var_file = var_file.path if var_file else "null",
        packer_path = ctx.file._packer.path,
        sha256_var_name = ctx.attr.sha256_var_name if ctx.attr.sha256_var_name else "null",
        iso_img_loc = path
    )
    pyscript_content = '{' + pyscript_content + '}'
    pyscript_input = ctx.actions.declare_file("run-" + ctx.attr.name + ".input.json")

    ctx.actions.write(
        output = pyscript_input,
        content = pyscript_content,
    )

    script = "python " + ctx.executable._deployment_script.path + " " + pyscript_input.path + "\n"

    # pump the command into a file
    ctx.actions.write(
        output = run,
        content = script,
        is_executable = True
    )

    # and execute it
    ctx.actions.run(
        executable = run,
        env = env,
        inputs = [x for x in [packerfile, var_file] if x != None] + ctx.files.deps + [pyscript_input] + ctx.attr.input_img.files.to_list(), # Look, i know it's stupid
        outputs = [out],
        use_default_shell_env = False,
        mnemonic = "Packer",
        tools = [ctx.file._packer, ctx.executable._deployment_script]
    )

    return [DefaultInfo(files=depset([out]))]

packer_qemu = rule(
    implementation = _packer_qemu_impl,
#    toolchains = ["//packer:toolchain_type"],
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
        "input_img": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "input_img_fmtstring": attr.string(
            default = "file://{{ env `PWD` }}/{input_img}",
        ),
        "input_img_subs_key": attr.string(
            default = "{iso}"
        ),
        "sha256_var_name": attr.string(),
        "substitutions": attr.string_dict(), # NOTE: Substitutes in the templates
        "vars": attr.string_dict(), # NOTE: passed as CLI args
        "env": attr.string_dict(), # NOTE: passed to the packer command
        "deps": attr.label_list(
            allow_files = True
        ),
        "_deployment_script": attr.label(
            allow_single_file = True,
            default = "//:packer2.py", # NOTE: this script is used to handle the "overwrite" flag properly
            executable = True,
            cfg = "exec"
        ),
        "debug": attr.bool(
            default = PACKER_DEBUG
        ),
        "_packer": attr.label(
            allow_single_file = True,
            default = "@packer//:" + PACKER_BIN_NAME # TODO: Toolchain here?
        )
    }
)
