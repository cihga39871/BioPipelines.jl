module BioPipelines

using Reexport

include(joinpath("..", "config", "Config.jl"))
@reexport using .Config


include(joinpath("Trimming", "Trimming.jl"))
@reexport using .Trimming

end
