_dep_masurca() = CmdDependency(
    exec = `$(Config.path_masurca)`,
    test_args = `--version`,
    validate_stdout = x -> occursin("version ", x)
)
_prog_masurca() = JuliaProgram(
    name             = "MaSuRCA Assembly",
    id_file          = ".assembly.masurca",
    cmd_dependencies = [dep_masurca],
    inputs           = [
        "ILLUMINA_R1" => "" => String,
        "ILLUMINA_R2" => "" => String,
        "LONG_READS" => "" => String,
        :THREADS => 1 => Int
    ],
    validate_inputs  = do_nothing,
    prerequisites    = do_nothing,
    main             = quote
        mkpath(TMPDIR, mode=0o755)

        # define sample inputs
        has_r1 = length(ILLUMINA_R1) > 0
        has_r2 = length(ILLUMINA_R2) > 0
        has_long = length(LONG_READS) > 0

        INPUT_ARGS = if has_r1 && has_r2 && has_long
            `-i $ILLUMINA_R1,$ILLUMINA_R2 -r $LONG_READS`
        elseif has_r1 && has_r2 && !has_long
            `-i $ILLUMINA_R1,$ILLUMINA_R2`
        elseif has_r1 && !has_r2 && has_long
            `-i $ILLUMINA_R1 -r $LONG_READS`
        elseif has_r1 && !has_r2 && !has_long
            `-i $ILLUMINA_R1`
        elseif !has_r1 && !has_r2 && has_long
            `-r $LONG_READS`
        else
            error("No input sequences!")
        end

        run(Cmd(`$dep_masurca $INPUT_ARGS -t $THREADS -o $TMPDIR/assemble.sh`, dir=TMPDIR))

        primary_fa = joinpath(TMPDIR, "CA", "primary.genome.scf.fasta")
        alternative_fa = joinpath(TMPDIR, "CA", "alternative.genome.scf.fasta")
        genome_qc = joinpath(TMPDIR, "CA", "genome.qc")

        @assert isfile(primary_fa)
        @assert isfile(alternative_fa)
        @assert isfile(genome_qc)

        mkpath(OUTDIR, mode=0o755)
        mv(primary_fa, PRIMARY_FA)
        mv(alternative_fa, ALTERNATIVE_FA)
        mv(genome_qc, GENOME_QC)

        rm(TMPDIR, recursive=true)
    end,
    infer_outputs    = do_nothing,
    outputs          = [
        "OUTDIR" => "masurca_out" => String, 
        "TMPDIR" => "<OUTDIR>.masurca.tmp",
        "PRIMARY_FA" => String => "<OUTDIR>/primary.genome.scf.fasta",
        "ALTERNATIVE_FA" => String => "<OUTDIR>/alternative.genome.scf.fasta",
        "GENOME_QC" => String => "<OUTDIR>/genome.qc",
    ],
    validate_outputs = quote
        isfile(PRIMARY_FA) &&
        isfile(ALTERNATIVE_FA) &&
        isfile(GENOME_QC)
    end,
    wrap_up          = do_nothing,
    arg_forward      = ["THREADS" => :ncpu],
    mod              = @__MODULE__
)
