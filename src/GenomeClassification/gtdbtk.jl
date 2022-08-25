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

_prog_gtdbtk_de_novo_wf() = CmdProgram(
    mod = @__MODULE__,
    name = "Gtdb-tk De Novo Workflow",
    id_file = ".gtdbtk.dnw",
    cmd_dependencies = [dep_gtdbtk],
    inputs = [
        "GENOME_DIR" => String,
        :THREADS => Int => 8,
        "EXTENSION" => String => "fna",
        "BACTERIA_OR_ARCHAEA" => String => "--bacteria",
        "OUTGROUP_TAXON" => String => "p__Patescibacteria",
        "OTHER_ARGS" => Cmd => ``
    ],
    validate_inputs = quote
        if !(BACTERIA_OR_ARCHAEA in ["--bacteria", "--archaea"])
            @error "BACTERIA_OR_ARCHAEA has to be --bacteria or --archaea"
            return false
        end
    end,
    outputs = "OUTPUT_DIR" => String => "<GENOME_DIR>/gtdbtk_de_novo_classify",
    cmd = `$dep_gtdbtk de_novo_wf --genome_dir GENOME_DIR BACTERIA_OR_ARCHAEA --out_dir OUTPUT_DIR -x EXTENSION --cpus THREADS --outgroup_taxon OUTGROUP_TAXON OTHER_ARGS`
)