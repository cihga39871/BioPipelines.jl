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

_prog_checkm_lineage_wf() = CmdProgram(
    name             = "CheckM Lineage Workflow",
    id_file          = ".qc.checkm",
    cmd_dependencies = [dep_checkm],
    inputs           = [
        "INPUT-DIR" => String,
        :THREADS => Int => 8,
        "EXTENSION" => String => "fna",
        "OTHER-ARGS" => Cmd => Config.args_checkm_lineage_wf
    ],
    outputs          = [
        "OUTPUT-DIR" => String => "<INPUT-DIR>/checkm",
        "TMP-DIR" => String => "<INPUT-DIR>/checkm_tmp",
        "FILE" => String => "<OUTPUT-DIR>/checkm.stdout"
    ],
    validate_inputs  = i -> check_dependency_dir(i["INPUT-DIR"]),
    cmd              = `$dep_checkm lineage_wf -t THREADS --pplacer_threads THREADS --extension EXTENSION --tmpdir TMP-DIR --file FILE OTHER-ARGS INPUT-DIR OUTPUT-DIR`
)