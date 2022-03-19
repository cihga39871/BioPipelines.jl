dep_samtools = CmdDependency(
    exec = `$(Config.path_to_samtools)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"samtools \d", x)
)
