_dep_gtdbtk() = CmdDependency(
    exec = `$(Config.path_gtdbtk)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"version \d", x)
)

_prog_gtdbtk_classify_wf() = CmdProgram(
    name = "Gtdb-tk Classify Workflow",
    id_file = ".gtdbtk.cw",
    cmd_dependencies = [dep_gtdbtk],
    inputs = [
        "GENOME_DIR" => String,
        :THREADS => Int => 8,
        "EXTENSION" => String => "fna",
        "OTHER_ARGS" => Cmd => ``
    ],
    outputs = "OUTPUT_DIR" => String => "<GENOME_DIR>/gtdbtk_classify",
    cmd = `$dep_gtdbtk classify_wf --genome_dir GENOME_DIR --out_dir OUTPUT_DIR -x EXTENSION --cpus THREADS --pplacer_cpus THREADS OTHER_ARGS`
)