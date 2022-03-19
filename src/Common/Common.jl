module Common

using Pipelines
using ..Config

include("julia.jl")
export dep_julia

include("samtools.jl")
export dep_samtools

end
