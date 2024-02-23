module Mapping

using Pipelines
using ..Config

using ..Common

include("bwa.jl")
export dep_bwa, prog_bwa

include("bwa-mem2.jl")
export dep_bwa_mem2, prog_bwa_mem2

include("minimap2.jl")
export dep_minimap2, prog_minimap2_index, prog_minimap2

end
