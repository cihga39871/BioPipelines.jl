_dep_julia() = CmdDependency(
    exec = `$(Base.julia_cmd()) --project=$(dirname(Pkg.project().path))`,
    test_args = `--version`
)

_prog_julia() = CmdProgram(
    name             = "Julia",
    id_file          = ".common.julia",
    cmd_dependencies = [dep_julia],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_julia ARGS`
)
