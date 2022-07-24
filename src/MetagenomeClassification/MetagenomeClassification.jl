module MetagenomeClassification

using Pipelines
using ..Config

using ..Common

include("kraken2.jl")
export dep_kraken2, prog_kraken2

end
