
"""
The Config module stores the paths and arguments of commandline.

If you want to change variables in this file, please change it in `config.secret.jl`. Any changes to `Config.jl` file might be recorded to Github, while `config.secret.jl` will not save to Github.
"""
module Config

isfile(joinpath(@__DIR__, "config.secret.jl")) || touch(joinpath(@__DIR__, "config.secret.jl"))

## Dependencies
path_to_atria = "atria"
args_to_atria = `--check-identifier --polyG`

## The previous settings will be override by the secret configure file
include("config.secret.jl")
end
