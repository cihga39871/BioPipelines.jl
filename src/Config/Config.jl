
"""
The Config module stores the paths and arguments of commandline.

If you want to change variables in this file, please change it in `config.secret.jl`. Any changes to `Config.jl` file might be recorded to Github, while `config.secret.jl` will not save to Github.

In addition, you can also create a config file named `.BioPipelinesConfig.jl` in your home directory.
"""
module Config

export update_config, get_config

isfile(joinpath(@__DIR__, "config.secret.jl")) || touch(joinpath(@__DIR__, "config.secret.jl"))

## Dependencies

# Common
path_samtools = "samtools"

# QC
path_fastqc = "fastqc"
path_multiqc = "multiqc"

# Trimming
path_atria = "atria"
args_atria = `--check-identifier --polyG`

# Mapping
path_bwa = "bwa"
args_bwa = ``

path_bwa_mem2 = "bwa-mem2"
args_bwa_mem2 = ``

# Assembly
path_velveth = "velveth"
path_velvetg = "velvetg"
path_velvet_optimizer = "VelvetOptimiser.pl"
args_velveth = ``
args_velvetg = ``
args_velvet_optimizer = ``

# Accession to Taxonomy database; a file ending with sql (taxonomizr)
path_taxonomizr_db = abspath(@__DIR__, "..", "..", "db", "taxonomizr", "accessionTaxa.sql")

## The previous settings will be override by the secret configure file
function update_config(config_file::AbstractString; verbose::Bool = true)
    if isfile(config_file)
        try
            @eval Config include($config_file)
            verbose && (@info "BioPipelines: Loading configuration: $config_file")
        catch
            error("BioPipelines: Loading configuration failed: $config_file")
            rethrow()
        end
    elseif verbose
        error("BioPipelines: Loading configuration failed: file not exist: $config_file")
    end
end

"""
    get_config(var::Symbol, default=nothing)

Get `var`iable defined in BioPipelines.Config module. If `var` is not defined, return `default`.
"""
@noinline function get_config(var::Symbol, default=nothing)
    if isdefined(Config, :var)
        getfield(Config, var)
    else
        default
    end
end

update_config(joinpath(@__DIR__, "config.secret.jl"); verbose = false)
update_config(joinpath(homedir(), ".BioPipelinesConfig.jl"); verbose = false)

SCRIPTS_DIR = abspath(@__DIR__, "..", "scripts")
SCRIPTS = Dict{String, String}(
    [(replace(s, r"\.jl$" => ""), joinpath(SCRIPTS_DIR, s)) for s in readdir(SCRIPTS_DIR)]
)



end
