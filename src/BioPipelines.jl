module BioPipelines

using Reexport

include(joinpath("..", "config", "Config.jl"))
@reexport using .Config

include(joinpath("Common", "Common.jl"))
@reexport using .Common

include(joinpath("Trimming", "Trimming.jl"))
@reexport using .Trimming

include(joinpath("Mapping", "Mapping.jl"))
@reexport using .Mapping

end
