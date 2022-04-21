module QC

using Pipelines
using ..Config

include("fastqc.jl")
export dep_fastqc, prog_fastqc

include("multiqc.jl")
export dep_multiqc

end
