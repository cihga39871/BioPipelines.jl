dep_julia = CmdDependency(
    exec = `$(Base.julia_cmd())`,
    test_args = `--version`
)

prog_julia = CmdProgram(
    name             = "Julia",
    id_file          = ".common.julia",
    cmd_dependencies = [dep_julia],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_julia ARGS`
)
