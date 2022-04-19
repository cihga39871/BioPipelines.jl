module BioPipelines

using Reexport

include(joinpath("Config", "Config.jl"))
@reexport using .Config

include(joinpath("Common", "Common.jl"))
@reexport using .Common

include(joinpath("Trimming", "Trimming.jl"))
@reexport using .Trimming

include(joinpath("Mapping", "Mapping.jl"))
@reexport using .Mapping

include(joinpath("Assembly", "Assembly.jl"))
@reexport using .Assembly

end
