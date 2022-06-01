_dep_checkm() = CmdDependency(
    exec = `$(Config.path_checkm)`,
    test_args = ``,
    validate_stdout = x -> occursin("lineage_wf", x)
)

_prog_checkm() = CmdProgram(
    name             = "CheckM",
    id_file          = ".qc.checkm",
    cmd_dependencies = [dep_checkm],
    inputs           = [
        "CMD" => Cmd => ``
    ],
    cmd              = `$dep_checkm CMD`
)

_prog_checkm_lineage_wf() = @pkg CmdProgram(
    name             = "CheckM Lineage Workflow",
    id_file          = ".qc.checkm",
    cmd_dependencies = [dep_checkm],
    inputs           = [
        "INPUT_DIR" => String,
        :THREADS => Int => 8,
        "EXTENSION" => String => "fna",
        "OTHER_ARGS" => Cmd => Config.args_checkm_lineage_wf
    ],
    outputs          = [
        "OUTPUT_DIR" => String => "<INPUT-DIR>/checkm",
        "TMP_DIR" => String => "<INPUT-DIR>/checkm_tmp",
        "FILE" => String => "<OUTPUT-DIR>/checkm.stdout"
    ],
    validate_inputs  = quote
        check_dependency_dir(INPUT_DIR)
    end,
    prerequisites    = quote
        mkpath(TMP_DIR; mode = 0o755)
    end,
    cmd              = `$dep_checkm lineage_wf -t THREADS --pplacer_threads THREADS --extension EXTENSION --tmpdir TMP_DIR --file FILE OTHER_ARGS INPUT_DIR OUTPUT_DIR`
)
