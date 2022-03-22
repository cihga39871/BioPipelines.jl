dep_velveth = CmdDependency(
    exec = `$(Config.path_to_velveth)`,
    test_args = ``,
    validate_stdout = x -> occursin("Version ", x)
)
dep_velvetg = CmdDependency(
    exec = `$(Config.path_to_velvetg)`,
    test_args = ``,
    validate_stdout = x -> occursin("Version ", x)
)

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
        "OTHER-ARGS" => Cmd => Config.args_to_bwa_mem2
    ],
    validate_inputs  = i -> begin
        check_dependency_file(i["READ1"]) &&
        (isempty(i["READ2"]) || check_dependency_file(i["READ2"]))
    end,
    prerequisites    = (i,o) -> begin
        bwa_mem2_index(i["INDEX"])
    end,
    cmd              = pipeline(
        `$dep_bwa_mem2 mem -t THREADS OTHER-ARGS INDEX READ1 READ2`,
        `$dep_julia $(Config.SCRIPTS["sam_correction"])`, # remove error lines genrated by bwa
        `$dep_samtools view -@ THREADS-SAMTOOLS -b -o BAM`
    ),
    infer_outputs    = do_nothing,
    outputs          = [
        "BAM" => String=> "<READ1>.bam"
    ],
    validate_outputs = o -> begin
        isfile(o["BAM"])
    end,
    wrap_up          = do_nothing
)
