module BioPipelines

using Reexport
using PkgVersion
using ArgParse
using CodecZlib
using FASTX
using Pipelines
using Pkg
using RCall

export biopipelines_init

const VERSION = @PkgVersion.Version

include(joinpath("Config", "Config.jl"))
using .Config
export get_config, update_config

include(joinpath("Common", "Common.jl"))
@reexport using .Common

include(joinpath("QC", "QC.jl"))
@reexport using .QC

include(joinpath("Trimming", "Trimming.jl"))
@reexport using .Trimming

include(joinpath("Mapping", "Mapping.jl"))
@reexport using .Mapping

include(joinpath("Assembly", "Assembly.jl"))
@reexport using .Assembly

include("Scripts.jl")
using .Scripts

# updating after all modules are loaded
"""
    biopipelines_init()

If BioPipelines is precompiled, please manually call it just after loading BioPipelines. It will fix script and config errors.
"""
function biopipelines_init()
    Scripts.fix_scripts()
    Config.update_dep_and_prog()
    Config.update_config(joinpath(homedir(), ".BioPipelines", "config.jl"); verbose = false)
end

biopipelines_init()

end
