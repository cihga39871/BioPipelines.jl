dep_julia = CmdDependency(
    exec = `$(Base.julia_cmd())`,
    test_args = `--version`
)
