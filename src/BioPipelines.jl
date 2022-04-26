module BioPipelines

using Reexport

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

# updating after all modules are loaded
Config.update_dep_and_prog()
Config.update_config(joinpath(homedir(), ".BioPipelines", "config.jl"); verbose = false)

end
