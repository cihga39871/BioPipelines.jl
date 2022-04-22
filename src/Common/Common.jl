module Common

using Pipelines
using ..Config

include("julia.jl")
export dep_julia, prog_julia

include("cmd.jl")
export prog_cmd

include("samtools.jl")
export dep_samtools, prog_samtools

include("bam_filter.jl")
export prog_bam_filter

include("blast.jl")
export dep_blastn, prog_blastn,
dep_makeblastdb, prog_makeblastdb

end
