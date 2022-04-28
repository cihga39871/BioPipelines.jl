#!julia
# using Pkg
# installed_pkgs = Set(keys(Pkg.project().dependencies))
# for pkg in ["ArgParse", "FASTX", "CodecZlib"]
#     pkg in installed_pkgs || Pkg.add(pkg)
# end

using BioPipelines.FASTX
using BioPipelines.CodecZlib
using BioPipelines.ArgParse

function parsing_args(args)
    prog_discription = "Filter fasta records."
    settings = ArgParseSettings(description = prog_discription)
    @add_arg_table! settings begin
        "-i", "--input"
            help = "input fasta or fasta.gz"
            arg_type = String
            required = true
        "-o", "--output"
            help = "output filtererd fasta"
            default = stdout
        "-N", "--qname-file"
            help = "Only include in output sequences that whose read name is listed in FILE (incompatible with --qname)"
            arg_type = String
            default = ""
        "-n", "--qname"
            help = "Only include in output sequences that whose read name is listed in the argument (incompatible with --qname-file)"
            arg_type = String
            nargs = '*'
        "-O", "--not-ordered"
            help = "the qnames of fasta and file are not in the same order"
            action = :store_true
    end
    return parse_args(args, settings)
end

# cd("/mnt/nvme1/jiacheng/polychromedetector_test/pcd_out/pcc-2-mapping")
# append!(ARGS, ["-i", "2020-10-Site4-R1.atria.fastq.filter.bam.fa", "-o", "z.test.fasta", "-N", "2020-10-Site4-R1.atria.fastq.filter.bam.fablastn7.id_list"])
args = parsing_args(ARGS)

qname_file = args["qname-file"]
qnames = args["qname"]
if qname_file == ""
    if length(qnames) == 0
        error("one of --qname-file or --qname is required.")
    end
else  # qname_file != ""
    isfile(qname_file) || error("File not found: --qname-file $(qname_file)")
    if length(qnames) > 0
        @warn "--qname-file and --qname are provided. Assume read names are not ordered."
        args["no-ordered"] = true
    end
end


function parse_id_list!(d::Dict{String, Bool}, qname_file::AbstractString, qnames::Vector{String})
    if isfile(qname_file)
        open(qname_file, "r") do io
            while !eof(io)
                id = readline(io)
                d[id] = 1
            end
        end
    end
    if length(qnames) > 0
        for id in qnames
            d[id] = 1
        end
    end
    d
end

fasta_in = args["input"]
reader = if endswith(fasta_in, r".gz"i)
    FASTA.Reader(GzipDecompressorStream(open(fasta_in)))
else
    open(FASTA.Reader, fasta_in)
end

fasta_out = args["output"]
fasta_out_io = fasta_out isa String ? open(FASTA.Writer, fasta_out) : stdout
record = FASTA.Record()


if args["not-ordered"]
    id_list = Dict{String, Bool}()
    parse_id_list!(id_list, qname_file, qnames)

    while !eof(reader)
        read!(reader, record)
        if haskey(id_list, FASTA.identifier(record))
            write(fasta_out_io, record)
        end
    end

else # ordered fasta; either of qname_file or qnames
    if isfile(qname_file)
        id_io = open(qname_file, "r")

        while !eof(id_io) && !eof(reader)
            id = readline(id_io)

            while !eof(reader)
                read!(reader, record)
                fa_id = FASTA.identifier(record)
                if fa_id == id
                    write(fasta_out_io, record)
                    break
                end
            end
        end
    else
        nqname = length(qnames)
        id_i = 1
        while id_i <= nqname && !eof(reader)
            global id_i
            id = qnames[id_i]
            id_i += 1

            while !eof(reader)
                read!(reader, record)
                fa_id = FASTA.identifier(record)
                if fa_id == id
                    write(fasta_out_io, record)
                    break
                end
            end
        end
    end
end


if fasta_out isa String
    close(fasta_out_io)
end
