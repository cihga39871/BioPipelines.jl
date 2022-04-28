module Scripts

using ..Config
using ..BioPipelines

const SCRIPTS_DIR = abspath(@__DIR__, "scripts")
const SCRIPTS_DATA = Dict{String, Vector{UInt8}}(
    [(replace(s, r"\.jl$" => ""), read(joinpath(SCRIPTS_DIR, s))) for s in readdir(SCRIPTS_DIR)]
)

# check whether script files are available
# it might be not available when bundling in an app
function fix_scripts()
    scripts_available = length(SCRIPTS_DATA) == length(Config.SCRIPTS) && all(map(isfile, values(Config.SCRIPTS)))
    if !scripts_available
        new_script_dir = joinpath(homedir(), ".BioPipelines", "scripts", "$(BioPipelines.VERSION)")
        # if not writable, use tempdir
        new_script_dir = try
            mkpath(new_script_dir, mode=0o755)
        catch
            new_script_dir = joinpath(tempdir(), ".BioPipelines", "scripts", "$(BioPipelines.VERSION)")
            mkpath(new_script_dir, mode=0o755)
        end
        for (name, data) in SCRIPTS_DATA
            script_path = joinpath(new_script_dir, name)
            if !isfile(script_path)
                write(script_path, data)
            end
            Config.SCRIPTS[name] = script_path
        end
    end
    nothing
end

end
