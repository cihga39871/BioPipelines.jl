dep_fastqc = CmdDependency(
    exec = `$(Config.path_fastqc)`,
    test_args = `--version`,
    validate_stdout = x -> occursin("FastQC", x)
)

prog_fastqc = CmdProgram(
    name             = "FastQC",
    id_file          = "qc.fastqc",
    cmd_dependencies = [dep_fastqc],
    inputs           = [
        "FILE" => String,
        "OTHER_ARGS" => Cmd => ``
    ],
    validate_inputs  = i -> check_dependency_file(i["FILE"]),
    cmd              = `$dep_fastqc OTHER_ARGS FILE`
)
