
_prog_bam_filter() = CmdProgram(
    name             = "BAM Filtering",
    id_file          = ".common.bam_filter",
    cmd_dependencies = [dep_julia, dep_samtools],
    inputs           = [
        "BAM" => String,
        "ARGS" => Cmd => ``
    ],
    validate_inputs  = i -> check_dependency_file(i["BAM"]),
    outputs          = ["FILTERED_BAM" => String],
    infer_outputs    = i -> Dict("FILTERED_BAM" => replaceext(i["BAM"], "filter.bam")),
    cmd              = pipeline(
        `$dep_samtools view -h BAM`,
        `$dep_julia $(Config.SCRIPTS["bam_filter"]) ARGS`,
        `$dep_samtools view -b -o FILTERED_BAM`
    )
)
