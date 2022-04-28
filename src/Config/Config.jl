
"""
The Config module stores the paths and arguments of commandline.

If you want to change variables in this file, please create a config file named `.BioPipelines/config.jl` in your home directory.
"""
module Config

export update_config, get_config

## Dependencies

# Common
path_samtools = "samtools"
path_blastn = "blastn"
path_makeblastdb = "makeblastdb"
path_rscript = "Rscript"

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
path_taxonomizr_db = abspath(homedir(), ".BioPipelines", "db", "taxonomizr", "accessionTaxa.sql")

## The previous settings will be override by configure files

"""
    update_dep_and_prog()

The function will evaluate `dep_xxx = _dep_xxx()` and `prog_xxx = _prog_xxx()` under the submodules of BioPipelines. Please use it after all submodules are loaded.

Caution: No need to call it manually. If you use `update_config(config_file)`, the dependencies and programs are automatically updated if the config are refreshed.
"""
function update_dep_and_prog()
    pm = parentmodule(@__MODULE__)
    # find modules
    pm_mod_names = filter!(x -> isdefined(pm, x) && getfield(pm, x) isa Module && (getfield(pm, x) !== @__MODULE__) && (getfield(pm, x) !== pm), names(pm))
    pm_mods = [getfield(pm, x) for x in pm_mod_names]

    for pm_mod in pm_mods
        # find programs named with _dep_* or _prog_*
        funs = filter!(names(pm_mod, all=true)) do x
            occursin(r"^_(dep|prog)_", string(x)) && getfield(pm_mod, x) isa Function
        end
        for fun in funs
            dep_or_prog = Symbol(string(fun)[2:end])
            @eval pm_mod $(dep_or_prog) = $(getfield(pm_mod, fun))()
        end
    end
end


function update_config(config_file::AbstractString; verbose::Bool = true)
    if isfile(config_file)
        try
            @eval Config include($config_file)
            verbose && (@info "BioPipelines: Loading configuration: $config_file")
        catch
            error("BioPipelines: Loading configuration failed: $config_file")
            rethrow()
        end
        # update dep and programs
        update_dep_and_prog()
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


local SCRIPTS

function update_scripts(SCRIPTS_DIR = abspath(@__DIR__, "..", "scripts"))
    global SCRIPTS
    SCRIPTS = Dict{String, String}(
        [(replace(s, r"\.jl$" => ""), joinpath(SCRIPTS_DIR, s)) for s in readdir(SCRIPTS_DIR)]
    )
end

update_scripts()

end
