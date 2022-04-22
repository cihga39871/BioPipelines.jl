dep_samtools = CmdDependency(
    exec = `$(Config.path_samtools)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"samtools \d", x)
)

prog_samtools = CmdProgram(
    name             = "Samtools",
    id_file          = ".common.samtools",
    cmd_dependencies = [dep_samtools],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_samtools ARGS`
)
