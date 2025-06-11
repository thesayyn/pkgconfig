def _pc_import_lib_impl(rctx):
    includedir = rctx.path(rctx.attr.includedir)
    libdir = rctx.path(rctx.attr.libdir)
    if not includedir.exists:
        fail("includedir '{}' does not exist".format(rctx.attr.includedir))
    if not libdir.exists:
        fail("libdir '{}' does not exist".format(rctx.attr.libdir))

    include_hdrs = []

    for path in includedir.readdir():
        if path.is_dir:
            # TODO: find a way to do symlnik recursive more cleanly.
            for path in path.readdir():
                if not path.basename.endswith(".h"):
                    continue
                dest = str(path).removeprefix(str(includedir) + "/")
                rctx.symlink(path, dest)
                include_hdrs.append(dest)
            continue
        if not path.basename.endswith(".h"):
            continue
        rctx.symlink(path, path.basename)
        include_hdrs.append(path.basename)

    for path in libdir.readdir():
        if path.is_dir:
            # print("handle")
            continue
        rctx.symlink(path, path.basename)
        include_hdrs.append(path.basename)

    rctx.file(
        "BUILD.bazel",
        """
cc_import(
    name = "{name}",
    hdrs = {hdrs},
    linkopts = {linkopts},
    includes = {includes},
    deps = {deps},
    shared_library = "{libname}.dylib",
    static_library = "{libname}.a",
    target_compatible_with = [
        "@platforms//os:macos",
        "@platforms//cpu:aarch64",
    ],
    visibility = ["//visibility:public"]
)
        """.format(
            name = getattr(rctx.attr, "original_name", rctx.attr.libname.removeprefix("lib")),
            hdrs = include_hdrs,
            libname = rctx.attr.libname,
            linkopts = rctx.attr.linkopts,
            # to allow <> (angled brackets) in user site includes, we need to add
            # external/repo_name so that Bazel adds a -I for it.
            includes = ["external/" + rctx.attr.name + "/" + include for include in rctx.attr.includes],
            deps = [str(dep) for dep in rctx.attr.deps],
        ),
    )

pc_import_lib = repository_rule(
    implementation = _pc_import_lib_impl,
    attrs = {
        "includedir": attr.string(),
        "libdir": attr.string(),
        "libname": attr.string(),
        "linkopts": attr.string_list(),
        "includes": attr.string_list(),
        "deps": attr.label_list(),
    },
)

def _expand_value(value, variables):
    # fast path
    if value.find("$") == -1:
        return value

    expanded_value = ""
    key = ""
    in_subs = False

    def assert_in_subs():
        if not in_subs:
            fail("corrupted pc file")

    for c in value.elems():
        if c == "$":
            in_subs = True
        elif c == "{":
            assert_in_subs()
        elif c == "}":
            assert_in_subs()
            value_of_key = variables[key]

            # reset subs state
            key = ""
            in_subs = False
            if not value_of_key:
                fail("corrupted pc file")
            expanded_value += value_of_key
        elif in_subs:
            key += c
        else:
            expanded_value += c

    return expanded_value

def _parse_pc(pc):
    variables = {}
    directives = {}
    for l in pc.splitlines():
        if l.startswith("#"):
            continue
        if not l.strip():
            continue
        if l.find("=") != -1:
            (k, v) = _split_once(l, "=")
            variables[k] = _expand_value(v, variables)
        elif l.find(":") != -1:
            (k, v) = _split_once(l, ":")
            directives[k] = _expand_value(v.removeprefix(" "), variables)
    return (directives, variables)

def _find_pkg_config(mctx, name, paths):
    for path in paths:
        looking = "%s/%s.pc" % (path, name)
        looking = mctx.path(looking)
        if looking.exists:
            pc = _parse_pc(mctx.read(looking))
            return (looking, pc)
    return (None, None)

def _split_once(l, sep):
    values = l.split(sep, 1)
    if len(values) < 2:
        fail("corrupted pc config")
    return (values[0], values[1])

def _parse_requires(re):
    if not re:
        return []
    deps = re.split(",")
    return [dep.strip(" ") for dep in deps if dep.strip(" ")]

def _trim(str):
    return str.rstrip(" ").lstrip(" ")

def pkgconfig_module_impl(mctx):
    found_deps = {}
    finding_attempts = {}

    root_module_direct_deps = []
    for module in mctx.modules:
        if not module.is_root:
            fail("pkgconfig should only be used in root module")
            continue
        paths = []
        isolate = False

        unresolved_transitives = [lib.name for lib in module.tags.lib]
        root_module_direct_deps = [lib.name for lib in module.tags.lib]
        for setup in module.tags.setup:
            paths.extend(setup.paths)
            isolate = setup.isolate

        for _ in range(100000000):
            if len(unresolved_transitives) == 0:
                break
            name = unresolved_transitives.pop()
            if name in found_deps:
                continue

            # Check attempts
            attempts = finding_attempts[name] if name in finding_attempts else 0
            if attempts > 3:
                fail("could not find package {} in all 3 attempts.", name)
            finding_attempts[name] = attempts + 1

            # type: string, tuple
            found_at, pkgconfig = _find_pkg_config(mctx, name, paths)
            if not pkgconfig:
                print("could not resolve '{}'".format(name))
                continue
            (directives, variables) = pkgconfig

            # Determine if the pkconfig found is a system installed package
            # that points to macOS.sdk as the includedir and /usr/lib as the
            # libdir.
            if isolate and str(found_at).find("Homebrew/os") != -1:
                packagen = found_at.basename.removesuffix(".pc")
                r = mctx.execute(["brew", "--prefix", packagen])
                if r.return_code:
                    print(r.stderr, r.stdout)
                pkgconfig_path = r.stdout.rstrip("\n") + "/lib/pkgconfig"
                paths.insert(0, pkgconfig_path)
                unresolved_transitives.insert(0, name)
                print("WARN: package {} is keg-only package, retrying with {}".format(name, pkgconfig_path))
                continue

            deps = []
            if "Requires" in directives:
                deps.extend(_parse_requires(directives["Requires"]))
            if "Requires.private" in directives:
                deps.extend(_parse_requires(directives["Requires.private"]))

            unresolved_transitives.extend(deps)
            found_deps[name] = (directives, variables, deps)

    for name, (directives, variables, deps) in found_deps.items():
        libname = name
        includedir = _trim(variables["includedir"])
        libdir = _trim(variables["libdir"])
        linkopts = []
        includes = []
        if "Libs" in directives:
            libs = _trim(directives["Libs"]).split(" ")
            for arg in libs:
                if arg.startswith("-l"):
                    if libname != name:
                        fail("unexpected a second -l")
                    libname = "lib" + arg.removeprefix("-l")
                    continue
                if arg.startswith("-L"):
                    continue
                linkopts.append(arg)

        if "Libs.private" in directives:
            libs = _trim(directives["Libs.private"]).split(" ")
            linkopts.extend([arg for arg in libs if arg.startswith("-l")])

        if "Cflags" in directives:
            cflags = _trim(directives["Cflags"]).split(" ")
            has_parent_include = False
            has_direct_include = False
            parent_include_dir = None
            rincludes = []
            for flag in cflags:
                if flag.startswith("-I"):
                    include = flag.removeprefix("-I")
                    if include == includedir:
                        has_direct_include = True
                    elif includedir.startswith(include):
                        has_parent_include = True
                        parent_include_dir = include
                    rincludes.append(include)

            if has_direct_include and has_parent_include:
                includedir = parent_include_dir

            for include in rincludes:
                rel = include.removeprefix(includedir)
                includes.append("." + rel)

        pc_import_lib(
            name = name,
            libname = libname,
            includedir = includedir,
            libdir = libdir,
            linkopts = linkopts,
            includes = includes,
            deps = ["@" + dep for dep in deps],
        )

    return mctx.extension_metadata(
        root_module_direct_deps = root_module_direct_deps,
        root_module_direct_dev_deps = [],
    )

pkgconfig = module_extension(
    implementation = pkgconfig_module_impl,
    tag_classes = {
        "setup": tag_class(
            attrs = {
                "paths": attr.string_list(),
                "isolate": attr.bool(),
            },
        ),
        "lib": tag_class(
            attrs = {
                "name": attr.string(),
            },
        ),
    },
)
