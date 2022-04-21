dep_multiqc = CmdDependency(
    exec = `$(Config.path_multiqc)`,
    test_args = `--version`,
    validate_stdout = x -> occursin("multiqc", x)
)
