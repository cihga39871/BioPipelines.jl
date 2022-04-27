using BioPipelines
using Test

@testset "BioPipelines.jl" begin
    include("common.jl")
    include("trimming.jl")
    include("mapping.jl")
end
