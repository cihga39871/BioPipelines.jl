dep_velveth = CmdDependency(
    exec = `$(Config.path_velveth)`,
    test_args = ``,
    validate_stdout = x -> occursin("Version ", x)
)
dep_velvetg = CmdDependency(
    exec = `$(Config.path_velvetg)`,
    test_args = ``,
    validate_stdout = x -> occursin("Version ", x)
)
#TODO
prog_velvet = JuliaProgram(
    name             = "Velvet Assembly",
    id_file          = "assembly.velvet",
    cmd_dependencies = [dep_velveth, dep_velvetg],
    inputs           = [
        "INDEX" => String,
        "READ1" => String,
        "READ2" => Union{String, Cmd} => ``,
        "THREADS" => Int => 8,
        "THREADS-SAMTOOLS" => Int => 4,
        "OTHER-ARGS-VELVETH" => Cmd => Config.args_velveth,
        "OTHER-ARGS-VELVETG" => Cmd => Config.args_velvetg
    ],
    validate_inputs  = i -> begin
        check_dependency_file(i["READ1"]) &&
        (isempty(i["READ2"]) || check_dependency_file(i["READ2"]))
    end,
    prerequisites    = (i,o) -> begin
        #TODO
    end,
    main             = (i,o) -> begin
        #TODO
    end,
    infer_outputs    = do_nothing,
    outputs          = [
        "FASTA" => String => "<READ1>.fa"
    ],
    validate_outputs = o -> begin
        isfile(o["BAM"])
    end,
    wrap_up          = do_nothing
)
