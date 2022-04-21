dep_multiqc = CmdDependency(
    exec = `$(Config.path_multiqc)`,
    test_args = `--version`,
    validate_stdout = x -> occursin("multiqc", x)
)

prog_multiqc = CmdProgram(
    name             = "MultiQC",
    id_file          = "qc.multiqc",
    cmd_dependencies = [dep_multiqc],
    inputs           = [
        "ANALYSIS_DIR" => String => ".",
        "OTHER_ARGS" => Cmd => ``
    ],
    outputs          = [
        "OUT_FILENAME" => String => "multiqc.html",
    ],
    validate_inputs  = i -> check_dependency_dir(i["ANALYSIS_DIR"]),
    prerequisites    = (i,o) -> begin
        outfile = o["OUT_FILENAME"]
        rm(outfile, force = true)
        rm(replace(outfile, ".html" => "_data"), force = true, recursive = true)
    end,
    cmd              = `$dep_multiqc --filename OUT_FILENAME OTHER_ARGS ANALYSIS_DIR`,
    validate_outputs = o -> isfile(o["OUT_FILENAME"])
)
