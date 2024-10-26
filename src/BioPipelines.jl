module BioPipelines

using Reexport
@reexport using Pipelines
using PkgVersion

using ArgParse
using CodecZlib
using FASTX
using Pkg
using DataFrames, DataFramesMeta, CSV, JSON, OrderedCollections  # QC/checkm, MetagenomeClassification/kraken2
using FASTX # MetagenomeClassification/kraken2

export biopipelines_init

const VERSION = @PkgVersion.Version

include(joinpath("Config", "Config.jl"))
using .Config
export get_config, update_config

include(joinpath("Common", "Common.jl"))
using .Common
export Common

include(joinpath("QC", "QC.jl"))
using .QC
export QC

include(joinpath("Trimming", "Trimming.jl"))
using .Trimming
export Trimming

include(joinpath("Mapping", "Mapping.jl"))
using .Mapping
export Mapping

include(joinpath("Assembly", "Assembly.jl"))
using .Assembly
export Assembly

include(joinpath("GenomeClassification", "GenomeClassification.jl"))
using .GenomeClassification
export GenomeClassification

include(joinpath("GenomeAnnotation", "GenomeAnnotation.jl"))
using .GenomeAnnotation
export GenomeAnnotation

include(joinpath("MetagenomeClassification", "MetagenomeClassification.jl"))
using .MetagenomeClassification
export MetagenomeClassification

include("Scripts.jl")
using .Scripts
export Scripts

include("utils.jl")
export merge_tables

include("FastProcessIOs.jl")
using .FastProcessIOs
export FastInputStream

# updating after all modules are loaded
"""
    biopipelines_init(;
        config_files = joinpath(homedir(), ".BioPipelines", "config.jl"),
        verbose::Bool = false, exit_when_fail::Bool = false,
        prepend_module_name::String = ""
    )

It initializes BioPipelines, including fix scripts, and update dependency and programs using config files.

You should call it *manually* for app building.

### Args of [`BioPipelines.Config.update_config`](@ref)

- `config_files`: `Vector` of config file paths, or `AbstractString` of the config file path.

- `verbose`: show config loading info or error.

- `exit_when_fail`: if config loading error, exit program.

- `resolve_dep_and_prog`: after loading config, run `update_dep_and_prog()`. *Caution*: you have to run `update_dep_and_prog()` before using any deps or progs. See also [`BioPipelines.Config.update_dep_and_prog`](@ref)

### Args of [`BioPipelines.Scripts.fix_scripts`](@ref)

If bundling in an app, please use `prepend_module_name = ".Mod"` in which `.Mod` using BioPipelines.
"""
function biopipelines_init(;
    config_files = joinpath(homedir(), ".BioPipelines", "config.jl"),
    verbose::Bool = false, exit_when_fail::Bool = false, resolve_dep_and_prog::Bool = true,
    prepend_module_name::String = ""
)
    Scripts.fix_scripts(;prepend_module_name = prepend_module_name)
    Config.update_config(config_files; verbose = verbose, exit_when_fail = exit_when_fail, resolve_dep_and_prog = false)
    resolve_dep_and_prog && Config.update_dep_and_prog()
end

function __init__()
    for ext in [".jl", ".R", ".py"]
        # If a file with an extension listed, infomation of this file will not write to run_id_file in Pipelines.
        if !(ext in Pipelines.RUN_ID_LINE_SKIP_EXTENSION)
            push!(Pipelines.RUN_ID_LINE_SKIP_EXTENSION, ext)
        end
    end
end

# do NOT move it to __init__()
biopipelines_init()

end
