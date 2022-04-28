
# Reference: https://samtools.github.io/hts-specs/SAMv1.pdf
# using Pkg
# installed_pkgs = Set(keys(Pkg.project().dependencies))
# for pkg in ["ArgParse"]
#     pkg in installed_pkgs || Pkg.add(pkg)
# end

using BioPipelines.ArgParse

function parsing_args(args)
    prog_usage = """samtools view -h BAM | $(@__FILE__) args... | samtools view -b -o FILTERED_BAM"""
    prog_discription = "Filter sam records."
    settings = ArgParseSettings(description = prog_discription, usage = prog_usage)
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
    if length(tag_str) < 6
        error("Invalid tag: $tag_str")
    end
    tag_str[1:2]
end

function tag_type(tag_str::AbstractString)
    type_dict = Dict(
        'A' => String,
        'i' => Int,
        'f' => Float64,
        'Z' => String,
        'H' => Vector{UInt8},
        'B' => Vector{Float64} # TODO: not exactly. see 1.5 section of https://samtools.github.io/hts-specs/SAMv1.pdf
    )

    if length(tag_str) < 6
        error("Invalid tag: $tag_str")
    end
    return type_dict[tag_str[4]]
end

function tag_value(tag_str::AbstractString)
    value_conversion_dict = Dict(
        'A' => String,
        'i' => x -> parse(Int, x),
        'f' => x -> parse(Float64, x),
        'Z' => String,
        'H' => hex2bytes,
        'B' => x -> error("Not supported tag conversion for B type: $tag_str") # TODO: not exactly. see 1.5 section of https://samtools.github.io/hts-specs/SAMv1.pdf
    )
    if length(tag_str) < 6
        error("Invalid tag: $tag_str")
    end
    return value_conversion_dict[tag_str[4]](tag_str[6:end])
end

function filter_tag(splitted::Vector{SubString{String}}, filter::BamTagFilter)
    n = length(splitted)
    if n < 12
        # no Tag
        return false
    end

    i = 12
    while i <= n
        tag_str = splitted[i]
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

function filter_map_quality(splitted::Vector{SubString{String}}, min_mq::Int = 0)
    n = length(splitted)
    if n < 5
        return false
    end
    return parse(Int, splitted[5]) >= min_mq
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
    flag = parse(Int, splitted[2])

    f_result = f & flag == f
    F_result = F & flag == 0
    G_result = G == 0 ? true : G & flag != G

    return f_result & F_result & G_result
end


### bam processing

# args
args = parsing_args(ARGS)

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
        filter_flag(splitted, f=$f, F=$F, G=$G) || (return false)
    end
end

MQ_PROCESS = if min_mq == 0
    nothing
else
    quote
        filter_map_quality(splitted, $min_mq) || (return false)
    end
end

TAG_PROCESS = if isempty(tag_filters)
    nothing
else
    quote
        all_or_any([filter_tag(splitted, filter) for filter in tag_filters]) || (return false)
    end
end

@eval function bam_filter_process(in::IO, out::IO, first_record_line)
    line = readline(in)
    isempty(line) && return

    if line[1] == '@'
        println(out, line)
        return true
    elseif first_record_line
        rand_id = abs(rand(Int8))
        args_str = join(ARGS, " ")
        println(out, "@PG\tID:bam_tag_filter.$rand_id\tPN:bam_tag_filter.jl\tCL:bam_tag_filter.jl $args_str")
    end

    splitted = split(line, '\t')

    $MQ_PROCESS
    $FLAG_PROCESS
    $TAG_PROCESS

    println(out, line)
    return false
end

function bam_filter_wrapper(in::IO, out::IO)

    first_record_line = true
    while !eof(in)
        first_record_line = bam_filter_process(stdin, stdout, first_record_line)
    end
end

bam_filter_wrapper(stdin, stdout)
