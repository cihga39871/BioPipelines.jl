_dep_atria() = CmdDependency(
    exec = `$(Config.path_atria)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"v\d+\.\d+\.\d+", x)
)

function infer_atria_outputs(in::Dict)
    file1 = in["READ1"]
    outdir = in["OUTPUT_DIR"]
    compress = in["COMPRESS"]
    if haskey(in, "READ2")
        file2 = in["READ2"]
        return Dict(
            "OUTPUT_R1" => infer_atria_outputs(file1, outdir, compress),
            "OUTPUT_R2" => infer_atria_outputs(file2, outdir, compress)
        )
    else
        return Dict(
            "OUTPUT_R1" => infer_atria_outputs(file1, outdir, compress)
        )
    end
end

function infer_atria_outputs(file1::String, outdir::String, compress::String)
    isingzip = occursin(r"\.gz$"i, file1)
    isinbzip2 = occursin(r"\.bz2$"i, file1)
    outcompress = uppercase(compress)
    if outcompress == "AUTO"
        if isingzip
            outcompress = "GZIP"
        elseif isinbzip2
            outcompress = "BZIP2"
        else
            outcompress = "NO"
        end
    elseif outcompress == "GZ"
        outcompress = "GZIP"
    elseif outcompress == "BZ2"
        outcompress = "BZIP2"
    end
    outfile1 = joinpath(outdir, replace(basename(file1), r"(fastq$|fq$|[^.]*)(\.gz|\.bz2)?$"i => s"atria.\1", count=1))

    if outcompress == "GZIP"
        outfile1 *= ".gz"
    elseif outcompress == "BZIP2"
        outfile1 *= ".bz2"
    end
    outfile1
end

_prog_atria() = CmdProgram(
    name             = "Atria Trimming (Paired-end)",
    id_file          = ".trimming.atria-pe",
    cmd_dependencies = [dep_atria],
    inputs           = [
        "READ1" => String,
        "READ2" => String,
        "ADAPTER1" => String => "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA",
        "ADAPTER2" => String => "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT",
        "OUTPUT_DIR" => String => ".",
        :THREADS => Int => 8,
        "COMPRESS" => String => "AUTO",
        "OTHER_ARGS" => Cmd => Config.args_atria
    ],
    validate_inputs  = do_nothing,
    prerequisites    = do_nothing,
    cmd              = `$dep_atria -o OUTPUT_DIR -a ADAPTER1 -A ADAPTER2 -t THREADS -g COMPRESS -r READ1 OTHER_ARGS -R READ2`,
    infer_outputs    = infer_atria_outputs,
    outputs          = [
        "OUTPUT_R1" => "auto generated; do not change",
        "OUTPUT_R2" => "auto generated; do not change"
    ],
    validate_outputs = o -> begin
        isfile(o["OUTPUT_R1"]) && isfile(o["OUTPUT_R2"])
    end,
    wrap_up          = do_nothing,
    arg_forward      = ["THREADS" => :ncpu]
)
_prog_atria_pe = _prog_atria

_prog_atria_se() = CmdProgram(
    name             = "Atria Trimming (Single-end)",
    id_file          = ".trimming.atria-se",
    cmd_dependencies = [dep_atria],
    inputs           = [
        "READ1" => String,
        "ADAPTER1" => String => "AGATCGGAAGAGCACACGTCTGAACTCCAGTCA",
        "OUTPUT_DIR" => String => ".",
        :THREADS => Int => 8,
        "COMPRESS" => String => "AUTO",
        "OTHER_ARGS" => Cmd => Config.args_atria
    ],
    validate_inputs  = do_nothing,
    prerequisites    = do_nothing,
    cmd              = `atria -o OUTPUT_DIR -a ADAPTER1 -t THREADS -g COMPRESS -r READ1 OTHER_ARGS`,
    infer_outputs    = infer_atria_outputs,
    outputs          = [
        "OUTPUT_R1" => "auto generated; do not change",
        "OUTPUT_R2" => "auto generated; do not change"
    ],
    validate_outputs = do_nothing,
    wrap_up          = do_nothing,
    arg_forward      = ["THREADS" => :ncpu]
)
