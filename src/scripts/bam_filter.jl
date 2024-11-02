
# Reference: https://samtools.github.io/hts-specs/SAMv1.pdf
# using Pkg
# installed_pkgs = Set(keys(Pkg.project().dependencies))
# for pkg in ["ArgParse"]
#     pkg in installed_pkgs || Pkg.add(pkg)
# end

using BioPipelines.ArgParse
# using ArgParse

using BioPipelines.BiBufferedStreams
# include("../FastProcessIO.jl")
# using .FastProcessIOs

function parsing_args(args)
    prog_usage = """samtools view -h BAM | $(@__FILE__) args... | samtools view -b -o FILTERED_BAM"""
    prog_discription = "Filter sam records."
    settings = ArgParseSettings(description=prog_discription, usage=prog_usage)
    @add_arg_table! settings begin
        "-f"
        help = "only include reads with all of the FLAGs in INT present"
        arg_type = Int
        default = 0
        "-F"
        help = "only include reads with none of the FLAGS in INT present"
        arg_type = Int
        default = 0
        "-G"
        help = "only EXCLUDE reads with all of the FLAGs in INT present"
        arg_type = Int
        default = 0
        "-q", "--min-MQ"
        help = "include reads with mapping quality >= INT"
        arg_type = Int
        default = 0
        "-t", "--tag-filter"
        help = "tag filters. Eg: (numeric) XX>4, XX<=5.69, XX=6.6, XX==6.6; (string) XX=string, XX:has:string"
        arg_type = String
        nargs = '*'
        "--any"
        help = "if multiple tag filters, include reads if any tag filter passes."
        action = :store_true
        "--stats"
        help = "output stats delim-splitted table file"
        default = "<stderr>"
        arg_type = String
        "--out", "-o"
        help = "output filtered sam file"
        default = "<stdout>"
        arg_type = String
    end
    return parse_args(args, settings)
end

##### tag filter
mutable struct BamTagFilter
    tag::String
    comparison::Function
    value::Any
end # struct

has(x::AbstractString, y::AbstractString) = occursin(y, x)

function BamTagFilter(argument::AbstractString)
    regex_numeric = r"([A-Z][A-Z])(<|<=|>|>=|=|==)([0-9.]+)"
    regex_string = r"([A-Z][A-Z])(=|==|:has:)(.+)"
    if occursin(regex_numeric, argument) # eg: AZ>15.5
        tag, comparison_str, value_str = match(regex_numeric, argument).captures
        if comparison_str == "="
            comparison_str == "=="
        end
        comparison = eval(Symbol(comparison_str))
        value = parse(Float64, value_str)
        return BamTagFilter(tag, comparison, value)

    elseif occursin(regex_string, argument) # eg: AZ=15.5
        tag, comparison_str, value_str = match(regex_string, argument).captures
        if comparison_str[1] == '='
            comparison = ==
        elseif comparison_str == ":has:"
            comparison = has
        end
        return BamTagFilter(tag, comparison, value_str)
    else
        error("Invalid argument: format not valid for tag filter. Numeric filter: XX>4, XX<=5.69, XX=6.6, XX==6.6; String filter XX=string, XX:has:string")
    end
end

function tag_name(tag_str::AbstractString)
    @inbounds view(tag_str, 1:2)
end

const value_conversion_dict = Dict(
    'A' => String,
    'i' => x -> parse(Int, x),
    'f' => x -> parse(Float64, x),
    'Z' => String,
    'H' => hex2bytes,
    'B' => x -> error("Not supported tag conversion for B type: $tag_str") # TODO: not exactly. see 1.5 section of https://samtools.github.io/hts-specs/SAMv1.pdf
)

function tag_value(tag_str::AbstractString)
    global value_conversion_dict
    return @inbounds value_conversion_dict[tag_str[4]](@view tag_str[6:end])
end

function filter_tag(splitted::Vector{SubString{String}}, filter::BamTagFilter)
    n = length(splitted)
    if n < 12
        # no Tag
        return false
    end

    i = 12
    while i <= n
        tag_str = @inbounds splitted[i]
        if length(tag_str) < 6
            error("Invalid tag: $tag_str")
        end
        if tag_name(tag_str) == filter.tag
            if filter.comparison(tag_value(tag_str), filter.value)
                return true
            else
                return false
            end
        end
        i += 1
    end
    return false
end # function

### mapping quality filter

function filter_map_quality(splitted::Vector{SubString{String}}, min_mq::Int=0)
    n = length(splitted)
    if n < 5
        return false
    end
    return parse(Int, @inbounds splitted[5]) >= min_mq
end

### flag filter
"""
    filter_flag(splitted::Vector{SubString{String}}; f::Int, F::Int, G::Int)

    f INT       only include reads with all  of the FLAGs in INT present [0]
    F INT       only include reads with none of the FLAGS in INT present [0x900]
    G INT       only EXCLUDE reads with all  of the FLAGs in INT present [0]
"""
function filter_flag(splitted::Vector{SubString{String}}; f::Int=0, F::Int=0, G::Int=0)
    n = length(splitted)
    if n < 2
        return false
    end
    flag = parse(Int, @inbounds splitted[2])

    f_result = f & flag == f
    F_result = F & flag == 0
    G_result = G == 0 ? true : G & flag != G

    return f_result & F_result & G_result
end


### bam processing

# args
args = parsing_args(ARGS)

file_sam = args["out"]
if file_sam == "<stdout>"
    io_sam = stdout
else
    io_sam = open(file_sam, "w+")
end

file_stats = args["stats"]
if file_stats == "<stderr>"
    io_stats = stderr
else
    io_stats = open(file_stats, "w+")
end

# stat preparation
mutable struct SamStats
    total_reads::Int64
    pass_all::Int64
    fail_flag::Int64
    fail_map_qual::Int64
    fail_tag::Int64
end
const sam_stats = SamStats(0, 0, 0, 0, 0)

# filter process

f = args["f"]
F = args["F"]
G = args["G"]
min_mq = args["min-MQ"]
tag_filters = BamTagFilter.(args["tag-filter"])
all_or_any = args["any"] ? any : all

FLAG_PROCESS = if f == 0 && F == 0 && G == 0
    nothing
else
    quote
        if !filter_flag(splitted, f=$f, F=$F, G=$G)
            sam_stats.fail_flag += 1
            return false
        end
    end
end

MQ_PROCESS = if min_mq == 0
    nothing
else
    quote
        if !filter_map_quality(splitted, $min_mq)
            sam_stats.fail_map_qual += 1
            return false
        end
    end
end

TAG_PROCESS = if isempty(tag_filters)
    nothing
else
    quote
        if !all_or_any([filter_tag(splitted, filter) for filter in tag_filters])
            sam_stats.fail_tag += 1
            return false
        end
    end
end

@eval function bam_filter_process(out::IO, line::AbstractString, sam_stats::SamStats)

    sam_stats.total_reads += 1

    splitted = split(line, '\t')

    $MQ_PROCESS
    $FLAG_PROCESS
    $TAG_PROCESS

    sam_stats.pass_all += 1
    println(out, line)

    return true
end

function bam_filter_wrapper(in, out::IO, sam_stats::SamStats)

    first_record_line = true
    while !eof(in)
        line = readline(in)
        isempty(line) && continue

        if line[1] == '@'
            println(out, line)
            continue
        elseif first_record_line
            rand_id = abs(rand(Int8))
            args_str = join(ARGS, " ")
            println(out, "@PG\tID:bam_tag_filter.$rand_id\tPN:bam_tag_filter.jl\tCL:bam_tag_filter.jl $args_str")
        end

        bam_filter_process(out, line, sam_stats)
        break
    end

    while !eof(in)
        line = readline(in)
        isempty(line) && continue
        bam_filter_process(out, line, sam_stats)
    end
end

in_stream = if v"1.11" <= VERSION < v"1.12"
    BiBufferedStream(stdin)
else
    stdin
end
precompile(readline, (typeof(in_stream),))
precompile(bam_filter_wrapper, (typeof(in_stream), typeof(io_sam), SamStats))

elapsed = @elapsed bam_filter_wrapper(in_stream, io_sam, sam_stats)

println(stderr, "Filter Bam: $elapsed seconds.")
io_sam isa Base.TTY || close(io_sam)


## sam stats
str_flag = "include all $f, include none $F, exclude all $G"
str_tag = join(args["tag-filter"], ",")

pct_pass = round(sam_stats.pass_all / sam_stats.total_reads * 100; digits=3)
pct_fail_flag = round(sam_stats.fail_flag / sam_stats.total_reads * 100; digits=3)
pct_fail_map_qual = round(sam_stats.fail_map_qual / sam_stats.total_reads * 100; digits=3)
pct_fail_tag = round(sam_stats.fail_tag / sam_stats.total_reads * 100; digits=3)

println(io_stats, "## Bam Filter")
println(io_stats, "## Command: ", Cmd(ARGS))
println(io_stats, "# Stats of Bam Filter")
println(io_stats, "total\t$(sam_stats.total_reads)\t100.000%\ttotal input reads")
println(io_stats, "passed\t$(sam_stats.pass_all)\t$pct_pass%\ttotal output reads")
println(io_stats, "failed flag\t$(sam_stats.fail_flag)\t$pct_fail_flag%\t$str_flag")
println(io_stats, "failed map quality\t$(sam_stats.fail_map_qual)\t$pct_fail_map_qual%\tmin quality $min_mq")
println(io_stats, "failed tag\t$(sam_stats.fail_tag)\t$pct_fail_tag%\t$str_tag")

io_stats isa Base.TTY || close(io_stats)
