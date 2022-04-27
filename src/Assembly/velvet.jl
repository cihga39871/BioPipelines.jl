_dep_velveth() = CmdDependency(
    exec = `$(Config.path_velveth)`,
    test_args = ``,
    validate_stdout = x -> occursin("Version ", x)
)
_dep_velvetg() = CmdDependency(
    exec = `$(Config.path_velvetg)`,
    test_args = ``,
    validate_stdout = x -> occursin("Version ", x)
)
_prog_velvet() = JuliaProgram(
    name             = "Velvet Assembly",
    id_file          = ".assembly.velvet",
    cmd_dependencies = [dep_velveth, dep_velvetg],
    inputs           = [
        "OUTDIR" => String,
        "HASH-LENGTH" => Int => 31,
        "ARGS-VELVETH" => Cmd => Config.args_velveth,
        "ARGS-VELVETG" => Cmd => Config.args_velvetg
    ],
    validate_inputs  = do_nothing,
    prerequisites    = (i,o) -> begin
        mkpath(i["OUTDIR"], mode=0o755)
    end,
    main             = (i,o) -> begin
        outdir = i["OUTDIR"]
        hash_length = i["HASH-LENGTH"]
        args_velveth = i["ARGS-VELVETH"]
        args_velvetg = i["ARGS-VELVETG"]
        run(`$dep_velveth $outdir $hash_length $args_velveth`)
        run(`$dep_velvetg $outdir $args_velvetg`)
        fasta = abspath(o["FASTA"])
        default_fasta = abspath(outdir, "contigs.fa")
        if fasta != default_fasta
            if !isfile(default_fasta)
                error("Velvet Assembly Failed: no contigs.fa under $outdir")
            end
            cp(default_fasta, fasta; force=true)
        end
        return o
    end,
    infer_outputs    = do_nothing,
    outputs          = [
        "FASTA" => String => "<OUTDIR>/contigs.fa"
    ],
    validate_outputs = o -> begin
        isfile(o["FASTA"])
    end,
    wrap_up          = do_nothing
)
