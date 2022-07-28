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
        lineage_df = get_full_lineage(FILE)
        bin_stat_df = get_bin_stats(BINSTAT)
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

mutable struct RankStat
    name::String
    completeness::Float64
    contamination::Float64
end
RankStat() = RankStat("", 0.0, 0.0)

mutable struct Lineage
    species::RankStat
    genus::RankStat
    family::RankStat
    order::RankStat
    class::RankStat
    phylum::RankStat
    kingdom::RankStat
end
Lineage() = Lineage(RankStat(), RankStat(), RankStat(), RankStat(), RankStat(), RankStat(), RankStat())

@eval function Base.getproperty(l::Lineage, s::Symbol)
    d = $(Dict([Symbol(String(f)[1]) => f for f in fieldnames(Lineage)]))
    field = get(d, s, s)
    getfield(l, field)
end
Base.getproperty(l::Lineage, s::AbstractString) = Base.getproperty(l::Lineage, Symbol(s))

function DataFrames.DataFrame(l::Lineage, sample_id::String = "NA")
    d = DataFrame(:sample => [sample_id])
    for rank in fieldnames(Lineage)
        v = getfield(l, rank)
        d[!, rank] = [v.name]
        d[!, Symbol(rank, "_completeness")] = [v.completeness]
        d[!, Symbol(rank, "_contamination")] = [v.contamination]
    end
    d
end

function get_full_lineage(lineage_marker_file; outfile = lineage_marker_file * ".tsv")
    df = parse_checkm_table(lineage_marker_file)
    
    # remove Marker_lineage == root
    filter!(:Marker_lineage => x -> occursin("__", x), df)
    
    if nrow(df) == 0
        df_lineages = DataFrame(Lineage(), "")
        @goto final
    end

    # get the highest completeness (the last row) of each Marker_lineage
    gdf_sample = groupby(df, :Bin_Id)
    df_sample_lineages = DataFrame[]
    for idf in gdf_sample
        sample_id = idf[1, :Bin_Id]
        df_sample = combine(last, groupby(idf, :Marker_lineage))
        select!(df_sample, :Bin_Id, All())
        @rtransform!(df_sample , $[:rank, :name] = split(:Marker_lineage, "__"))

        lineage = Lineage()
        for r in eachrow(df_sample)
            v = getproperty(lineage, r.rank)
            if v.completeness < r.Completeness
                # replace old
                v.name = r.name
                v.completeness = r.Completeness
                v.contamination = r.Contamination
            end
        end
        
        df_sample_lineage = DataFrame(lineage, sample_id)

        push!(df_sample_lineages, df_sample_lineage)
    end
    

    @label final
    df_lineages = vcat(df_sample_lineages...)
    sort!(df_lineages, :sample)

    CSV.write(outfile, df_lineages, delim='\t')
    return df_lineages
end

function get_bin_stats(file; outfile = file * ".real.tsv")
    lines = readlines(file)
    dfs_bin_stats = DataFrame[]
    for line in lines
        sample_id = nothing
        if length(line) == 0
            continue
        end
        splitted = split(line, '\t')
        if length(splitted) != 2
            @warn "Invalid bin_stats line" file line
            continue
        end

        sample_id = String(splitted[1])

        json = replace(splitted[2], '\'' => '"')
        dict = JSON.parse(json, dicttype = OrderedDict)

        res = DataFrame(:sample => sample_id)
        insertcols!(res, collect(dict)...)
        push!(dfs_bin_stats, res)
    end
    df_bin_stats = vcat(dfs_bin_stats...)
    sort!(df_bin_stats, :sample)
    CSV.write(outfile, df_bin_stats, delim='\t')
    return df_bin_stats
end
