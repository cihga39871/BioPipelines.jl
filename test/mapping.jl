dir = mktempdir(prefix = "BioPipeline_Mapping.")
@info "Testing Mapping at $dir"
cd(dir)

r1 = joinpath(@__DIR__, "test_R1.fastq.gz")
r2 = joinpath(@__DIR__, "test_R2.fastq.gz")
reference = joinpath(@__DIR__, "test_reference.fasta")
index = joinpath(dir, "test_reference.fasta")
cp(reference, index)

@testset "Mapping BWA" begin
    @test check_dependency(dep_bwa)

    inputs = [
        "INDEX" => index,
        "READ1" => r1
    ]
    outputs = "BAM" => "out.bam"
    ok, out = run(prog_bwa, inputs, outputs)
    @test ok
    @test isfile(out["BAM"])

    inputs = [
        "INDEX" => index,
        "READ1" => r1,
        "READ2" => r2
    ]
    outputs = "BAM" => "out2.bam"
    ok, out = run(prog_bwa, inputs, outputs)
    @test ok
    @test isfile(out["BAM"])
end

@testset "Mapping BWA-MEM2" begin
    @test check_dependency(dep_bwa_mem2)

    inputs = [
        "INDEX" => index,
        "READ1" => r1
    ]
    outputs = "BAM" => "out3.bam"
    ok, out = run(prog_bwa_mem2, inputs, outputs)
    @test ok
    @test isfile(out["BAM"])

    inputs = [
        "INDEX" => index,
        "READ1" => r1,
        "READ2" => r2
    ]
    outputs = "BAM" => "out4.bam"
    ok, out = run(prog_bwa_mem2, inputs, outputs)
    @test ok
    @test isfile(out["BAM"])
end

rm(dir, force=true, recursive=true)
