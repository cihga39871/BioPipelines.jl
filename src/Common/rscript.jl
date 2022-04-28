_dep_rscript() = CmdDependency(
    exec = `$(Config.path_rscript)`,
    test_args = `--version`,
    validate_success = true
)

_prog_rscript() = CmdProgram(
    name             = "Rscript",
    id_file          = ".common.rscript",
    cmd_dependencies = [dep_rscript],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_rscript ARGS`
)
