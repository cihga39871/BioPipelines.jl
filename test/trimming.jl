dir = mktempdir(prefix = "BioPipeline_Trimming.")
@info "Testing Trimming at $dir"
cd(dir)

r1 = joinpath(@__DIR__, "test_R1.fastq.gz")
r2 = joinpath(@__DIR__, "test_R2.fastq.gz")

@testset "Atria" begin
    @test check_dependency(dep_atria)

    inputs = [
        "READ1" => r1,
        "OUTPUT-DIR" => dir
    ]
    ok, out = run(prog_atria_se, inputs)
    @test ok
    @test isfile(out["OUTPUT-R1"])

    inputs = [
        "READ1" => r1,
        "READ2" => r2,
        "OUTPUT-DIR" => dir
    ]
    ok, out = run(prog_atria, inputs)
    @test ok
    @test isfile(out["OUTPUT-R1"])
    @test isfile(out["OUTPUT-R2"])
end

rm(dir, force=true, recursive=true)
