_dep_kraken2() = CmdDependency(
    exec = `$(Config.path_kraken2)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"version \d", x)
)

_prog_kraken2() = CmdProgram(
    name = "Kraken2",
    id_file = ".kraken2",
    cmd_dependencies = [dep_kraken2],
    inputs = [
        "INPUT_SEQ" => String,
        "DB" => String => Config.path_kraken2_db,
        :THREADS => Int => 8,
        "OTHER_ARGS" => Cmd => Config.args_kraken2
    ],
    outputs = [
        "UNCLASSIFIED_OUT" => String => "<INPUT_SEQ>.kraken2.unclassified.fa",
        "CLASSIFIED_OUT" => String => "<INPUT_SEQ>.kraken2.classified.fa",
        "OUTPUT" => String => "<INPUT_SEQ>.kraken2.out",
        "REPORT" => String => "<INPUT_SEQ>.kraken2.report"
    ],
    cmd = `$dep_kraken2 --db DB --threads THREADS --unclassified-out UNCLASSIFIED_OUT --classified-out CLASSIFIED_OUT --output OUTPUT --report REPORT OTHER_ARGS INPUT_SEQ`
)
