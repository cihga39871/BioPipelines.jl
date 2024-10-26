# CHANGE LOG

v0.3.11

- Optim: `scripts/bam_filter.jl` is faster because of my new `FastProcessIOs.jl`. 

**FastProcessIOs.jl Benchmark Using `samtools view -h -@10 BAM`:**

- 1.28x faster in Julia v1.10.4.
- 6.20x faster in Julia v1.11.1.


v0.3.8

- `Common.dep_julia`: add `--project` as current Pkg project because `Base.julia_cmd()` will ignore current project information, and lead to unsolved package dependency errors.