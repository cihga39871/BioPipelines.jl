module VariantCalling

using Pipelines
using ..Config

include("deepvariant.jl")
export dep_docker_check_deepvariant, prog_deepvariant

end
