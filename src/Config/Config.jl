
"""
The Config module stores the paths and arguments of commandline.

If you want to change variables in this file, please change it in `config.secret.jl`. Any changes to `Config.jl` file might be recorded to Github, while `config.secret.jl` will not save to Github.

In addition, you can also create a config file named `.BioPipelinesConfig.jl` in your home directory.
"""
module Config

isfile(joinpath(@__DIR__, "config.secret.jl")) || touch(joinpath(@__DIR__, "config.secret.jl"))

## Dependencies

# Common
path_to_samtools = "samtools"

# Trimming
path_to_atria = "atria"
args_to_atria = `--check-identifier --polyG`

# Mapping
path_to_bwa = "bwa"
args_to_bwa = ``

path_to_bwa_mem2 = "bwa-mem2"
args_to_bwa_mem2 = ``

# Assembly
path_to_velveth = "velveth"
path_to_velvetg = "velvetg"
path_to_velvet_optimizer = "VelvetOptimiser.pl"

# Accession to Taxonomy database; a file ending with sql (taxonomizr)
path_to_taxonomizr_db = abspath(@__DIR__, "..", "..", "db", "taxonomizr", "accessionTaxa.sql")

## The previous settings will be override by the secret configure file
try
    include("config.secret.jl")
catch
    error("Loading secret configuration file failed: $(joinpath(@__DIR__, "config.secret.jl"))")
    rethrow()
end

personal_config = joinpath(homedir(), ".BioPipelinesConfig.jl")
if isfile(personal_config)
    try
        include(personal_config)
    catch
        error("Loading personal configuration file failed: $personal_config")
        rethrow()
    end
end

SCRIPTS_DIR = abspath(@__DIR__, "..", "scripts")
SCRIPTS = Dict{String, String}(
    [(replace(s, r"\.jl$" => ""), joinpath(SCRIPTS_DIR, s)) for s in readdir(SCRIPTS_DIR)]
)
end
