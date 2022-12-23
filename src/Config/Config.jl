
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

path_checkm = "checkm"
args_checkm_lineage_wf = ``

# Trimming
path_atria = "atria"
args_atria = `--check-identifier --polyG`

# Mapping
path_bwa = "bwa"
args_bwa = ``

path_bwa_mem2 = "bwa-mem2"
args_bwa_mem2 = ``

# Assembly
path_masurca = "masurca"
path_velveth = "velveth"
path_velvetg = "velvetg"
path_velvet_optimizer = "VelvetOptimiser.pl"
args_velveth = ``
args_velvetg = ``
args_velvet_optimizer = ``

# GenomeClassification
path_gtdbtk = "gtdbtk"
env_gtdbtk = nothing  # not implemented

# MetagenomeClassification
path_kraken2 = "kraken2"
args_kraken2 = ``
path_kraken2_db = "none"

path_kma = "kma"
path_kma_db = "none"
args_kma = `-1t1 -mem_mode -and`

path_ccmetagen = "CCMetagen.py"

# Accession to Taxonomy database; a file ending with sql (taxonomizr)
path_taxonomizr_db = abspath(homedir(), ".BioPipelines", "db", "taxonomizr", "accessionTaxa.sql")

## The previous settings will be override by configure files

"""
    update_config(config_files; verbose::Bool = true, exit_when_fail::Bool = false, resolve_dep_and_prog::Bool = true)

- `config_files`: `Vector` of config file paths, or `AbstractString` of the config file path.

- `verbose`: show loading info or error.

- `exit_when_fail`: if loading error, exit program.

- `resolve_dep_and_prog`: after loading config, run `update_dep_and_prog()`.
"""
function update_config(config_file::AbstractString; verbose::Bool = true, exit_when_fail::Bool = false, resolve_dep_and_prog::Bool = true)
    if isfile(config_file)
        try
            @eval Config include($config_file)
            verbose && (@info "BioPipelines: Loading configuration: $config_file")
            # update dep and programs
            resolve_dep_and_prog && update_dep_and_prog()
            return true
        catch ex
            if exit_when_fail
                @error "BioPipelines: Loading configuration failed: $config_file"
                rethrow(ex)
            else
                @error "BioPipelines: Loading configuration failed: $config_file" exception=(ex,backtrace())
            end
            return false
        end
    else
        if exit_when_fail
            error("BioPipelines: Loading configuration failed: file not exist: $config_file")
        elseif verbose
            @error "BioPipelines: Loading configuration failed: file not exist: $config_file"
        end
        return false
    end
end
function update_config(config_files::Vector; verbose::Bool = true, exit_when_fail::Bool = false, resolve_dep_and_prog::Bool = true)
    updated = false
    for config_file in config_files
        res = update_config(config_file; verbose = verbose, exit_when_fail = exit_when_fail, resolve_dep_and_prog = false)
        if res
            updated = true
        end
    end
    if updated && resolve_dep_and_prog
        update_dep_and_prog()
    end
    return updated
end

"""
    get_config(var::Symbol, default=nothing)

Get `var`iable defined in BioPipelines.Config module. If `var` is not defined, return `default`.
"""
@noinline function get_config(var::Symbol, default=nothing)
    if isdefined(Config, var)
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

## dep and prog init
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

## function to run before precompile
update_scripts()

end
