module MetagenomeClassification

using Pipelines
using ..Config

using ..Common

using DataFrames, FASTX

include("kraken2.jl")
export dep_kraken2, prog_kraken2, kraken2_split_fasta_by_tax

end
