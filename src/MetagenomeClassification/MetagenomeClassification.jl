module MetagenomeClassification

using Pipelines
using ..Config

using ..Common

using DataFrames, FASTX, CSV

include("kma_and_ccmetagen.jl")
export dep_kma, prog_kma
export dep_ccmetagen, prog_ccmetagen

include("kraken2.jl")
export dep_kraken2, prog_kraken2, prog_kraken2_paired, kraken2_split_fasta_by_tax

end
