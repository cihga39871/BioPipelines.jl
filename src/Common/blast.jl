dep_blastn = CmdDependency(
    exec = `$(Config.path_blastn)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"samtools \d", x)
)

prog_blastn = CmdProgram(
    name             = "BLASTn",
    id_file          = ".common.blastn",
    cmd_dependencies = [dep_blastn],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_blastn ARGS`
)
