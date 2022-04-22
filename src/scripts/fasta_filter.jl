#!julia

using FASTX
using CodecZlib
using ArgParse

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
            arg_type = String
        "-N", "--qname-file"
            help = "Only include in output sequences that whose read name is listed in FILE"
            arg_type = String
    end
    return parse_args(args, settings)
end

#cd("/mnt/raid1-2/jiacheng/CharlottetownWater/ngs_datasets/2.map_to_S.endobioticum")
#append!(ARGS, ["-i", "2021-10-Site4-R1.atria.fastq.gz.BWA.bam.filter.bam.fasta", "-o", "z.test.fasta", "-N", "2021-10-Site4-R1.atria.fastq.gz.BWA.bam.filter.bam.fasta.blastn7.unique_id_list.txt"])
args = parsing_args(ARGS)

function parse_id_list!(d::Dict{String, Bool}, qname_file::AbstractString)
    isfile(qname_file) || (return d)
    open(qname_file, "r") do io
        while !eof(io)
            id = readline(io)
            d[id] = 1
        end
    end
    d
end

id_list = Dict{String, Bool}()
parse_id_list!(id_list, args["qname-file"])

fasta_in = args["input"]
reader = if endswith(fasta_in, r".gz"i)
    FASTA.Reader(GzipDecompressorStream(open(fasta_in)))
else
    open(FASTA.Reader, fasta_in)
end

fasta_out = args["output"]
fasta_out_io = fasta_out isa String ? open(FASTA.Writer, fasta_out) : stdout
record = FASTA.Record()
while !eof(reader)
    read!(reader, record)

    if haskey(id_list, FASTA.identifier(record))
        write(fasta_out_io, record)
    end
end

if fasta_out isa String
    close(fasta_out_io)
end
