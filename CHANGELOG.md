# CHANGE LOG

v0.3.8

- `Common.dep_julia`: add `--project` as current Pkg project because `Base.julia_cmd()` will ignore current project information, and lead to unsolved package dependency errors.