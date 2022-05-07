module Scripts

using ..Config
using ..BioPipelines

const SCRIPTS_DIR = abspath(@__DIR__, "scripts")
const SCRIPTS_DATA = Dict{String, String}(
    [(replace(s, r"\.jl$" => ""), read(joinpath(SCRIPTS_DIR, s), String)) for s in readdir(SCRIPTS_DIR)]
)


"""
    fix_scripts(;prepend_module_name::String = "")

Check whether script files are available. They might be not available when bundling in an app.

- `prepend_module_name`: If bundling in an app, please use `prepend_module_name = ".Mod"` in which `.Mod` loads BioPipelines and can be accessed from Main. It will modify scripts containing `using BioPipelines` or `import BioPipelines` by prepending the module names to `BioPipelines` to make sure the script can found BioPipelines from Main module.
"""
function fix_scripts(;prepend_module_name::String = "")
    scripts_available = length(SCRIPTS_DATA) == length(Config.SCRIPTS) && all(map(isfile, values(Config.SCRIPTS)))
    force_fix = prepend_module_name != ""
    if !scripts_available || force_fix
        new_script_dir = joinpath(homedir(), ".BioPipelines", "scripts", "$prepend_module_name.$(BioPipelines.VERSION)")
        # if not writable, use tempdir
        new_script_dir = try
            mkpath(new_script_dir, mode=0o755)
        catch
            new_script_dir = joinpath(tempdir(), ".BioPipelines", "scripts", "$prepend_module_name.$(BioPipelines.VERSION)")
            mkpath(new_script_dir, mode=0o755)
        end
        for (name, data) in SCRIPTS_DATA
            script_path = joinpath(new_script_dir, name)
            if !isfile(script_path)
                if prepend_module_name == ""
                    write(script_path, data)
                else
                    # replace `using BioPipelines.ArgParse` to `using .Mod.BioPipelines.ArgParse`
                    io = IOBuffer(data)
                    io_out = open(script_path, "w+")

                    while !eof(io)
                        line = readline(io)
                        if occursin(r" *using | *import ", line)
                            line = replace(line, "BioPipelines" => "$prepend_module_name.BioPipelines")
                        end
                        println(io_out, line)
                    end
                    close(io_out)
                end
            end
            Config.SCRIPTS[name] = script_path
        end
    end
    nothing
end

end
