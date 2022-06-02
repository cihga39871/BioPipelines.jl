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
    mod              = @__MODULE__,
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
        "OUTPUT_DIR" => String => "<INPUT_DIR>/checkm",
        "TMP_DIR" => String => "<INPUT_DIR>/checkm_tmp",
        "FILE" => String => "<OUTPUT_DIR>/checkm.stdout"
    ],
    validate_inputs  = quote
        check_dependency_dir(INPUT_DIR)
    end,
    prerequisites    = quote
        mkpath(TMP_DIR; mode = 0o755)
    end,
    cmd              = `$dep_checkm lineage_wf -t THREADS --pplacer_threads THREADS --extension EXTENSION --tmpdir TMP_DIR --file FILE OTHER_ARGS INPUT_DIR OUTPUT_DIR`
)


_prog_checkm_lineage_summary() = JuliaProgram(
    mod              = @__MODULE__,
    name             = "CheckM Lineage Summary",
    id_file          = ".qc.checkm.ls",
    cmd_dependencies = [dep_checkm],
    inputs           = [
        "DIR" => String,
        "LINEAGE_MS" => String => "<DIR>/lineage.ms",
        "BINSTAT" => String => "<DIR>/storage/bin_stats.analyze.tsv"
    ],
    outputs          = [
        "FILE" => String => "<DIR>/lineage.marker",
        Arg(:STAT_DF, nothing; required = false),
        "STAT_SUMMARY" => String => "<DIR>/stat_summary.tsv"
    ],
    validate_inputs  = quote
        check_dependency_dir(DIR) &&
        check_dependency_file(BINSTAT) &&
        check_dependency_file(LINEAGE_MS)
    end,
    main              = quote
        run(`$dep_checkm qa -o 3 -f $FILE $LINEAGE_MS $DIR`)
        lineage_df = get_full_lineage(FILE; sample_id = basename(DIR))
        bin_stat_df = get_bin_stats(BINSTAT; sample_id = basename(DIR))
        STAT_DF = leftjoin(bin_stat_df, lineage_df, on = :sample)
        CSV.write(STAT_SUMMARY, STAT_DF, delim='\t')
    end,
    validate_outputs = quote
        check_dependency_file(FILE)
        check_dependency_file(STAT_SUMMARY)
    end
)

function parse_checkm_table(file::AbstractString)
    buf = Vector{UInt8}()
    open(file) do io
        while !eof(io)
            line = readline(io)
            if length(line) == 0 || line[1] == '-'
                continue
            end
            line = replace(line, r"^ +| +$" => "", r"  +" => "\t") * "\n"
            append!(buf, line)
        end
    end
    CSV.read(buf, DataFrame; ntasks = 1, delim = '\t', normalizenames = true)
end

mutable struct Completeness
    name::String
    completeness::Float64
end
Completeness() = Completeness("", 0.0)

mutable struct Lineage
    species::Completeness
    genus::Completeness
    family::Completeness
    order::Completeness
    class::Completeness
    phylum::Completeness
    kingdom::Completeness
end
Lineage() = Lineage(Completeness(), Completeness(), Completeness(), Completeness(), Completeness(), Completeness(), Completeness())

@eval function Base.getproperty(l::Lineage, s::Symbol)
    d = $(Dict([Symbol(String(f)[1]) => f for f in fieldnames(Lineage)]))
    field = get(d, s, s)
    getfield(l, field)
end
Base.getproperty(l::Lineage, s::AbstractString) = Base.getproperty(l::Lineage, Symbol(s))

function DataFrames.DataFrame(l::Lineage)
    d = DataFrame()
    for rank in fieldnames(Lineage)
        v = getfield(l, rank)
        d[!, rank] = [v.name]
        d[!, Symbol(rank, "_completeness")] = [v.completeness]
    end
    d
end
function DataFrames.DataFrame(l::Lineage, sample_id::String)
    d = DataFrame(:sample => [sample_id])
    for rank in fieldnames(Lineage)
        v = getfield(l, rank)
        d[!, rank] = [v.name]
        d[!, Symbol(rank, "_completeness")] = [v.completeness]
    end
    d
end

function get_full_lineage(lineage_marker_file; sample_id = basename(dirname(lineage_marker_file)), outfile = lineage_marker_file * ".tsv")
    df = parse_checkm_table(lineage_marker_file)
    
    # remove Marker_lineage == root
    filter!(:Marker_lineage => x -> occursin("__", x), df)
    
    # get the highest completeness (the last row) of each Marker_lineage
    df_simple = combine(last, groupby(df, :Marker_lineage))

    lineage = Lineage()
    if nrow(df_simple) == 0
        @goto final
    end

    @rtransform!(df_simple , $[:rank, :name] = split(:Marker_lineage, "__"))

    for r in eachrow(df_simple)
        v = getproperty(lineage, r.rank)
        if v.completeness < r.Completeness
            v.completeness = r.Completeness
            v.name = r.name
        end
    end

    @label final
    res = DataFrame(lineage, sample_id)
    CSV.write(outfile, res, delim='\t')
    return res
end

function get_bin_stats(file; outfile = file * ".real.tsv", sample_id::String = "auto")
    line = readline(file)
    if length(line) == 0
        @goto final
    end
    splitted = split(line, '\t')
    if length(splitted) != 2
        @goto final
    end

    if sample_id == "auto"
        sample_id = String(splitted[1])
    end

    json = replace(splitted[2], '\'' => '"')
    dict = JSON.parse(json, dicttype = OrderedDict)


    @label final
    if sample_id == "auto"
        sample_id = "Invalid: $file"
    end
    res = DataFrame(:sample => sample_id)
    insertcols!(res, collect(dict)...)
    CSV.write(outfile, res, delim='\t')
    return res
end
