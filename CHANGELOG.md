# CHANGE LOG

v0.3.11

- Optim: `scripts/bam_filter.jl` is faster because of my new `FastProcessIO.jl`

- TODO: `FastProcessIO.jl` should asyncly read from source ::: `FastProcessIO_async.jl` shoule have no copyto between two buffers.

v0.3.8

- `Common.dep_julia`: add `--project` as current Pkg project because `Base.julia_cmd()` will ignore current project information, and lead to unsolved package dependency errors.