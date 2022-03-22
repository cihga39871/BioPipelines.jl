dir = mktempdir(prefix = "BioPipeline_Assembly.")
@info "Testing Assembly at $dir"
cd(dir)

r1 = joinpath(@__DIR__, "test_R1.fastq.gz")
r2 = joinpath(@__DIR__, "test_R2.fastq.gz")
reference = joinpath(@__DIR__, "test_reference.fasta")
index = joinpath(dir, "test_reference.fasta")
cp(reference, index)

@testset "Mapping BWA" begin
    @test check_dependency(dep_velveth)
    @test check_dependency(dep_velvetg)

end
rm(dir, force=true, recursive=true)
