module Common

using Pipelines
using ..Config

include("julia.jl")
export dep_julia, prog_julia

include("samtools.jl")
export dep_samtools, prog_samtools

include("bam_filter.jl")
export prog_bam_filter

end
