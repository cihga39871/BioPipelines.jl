
function main_cmd(i, o)
    run(i["CMD"])
    return Dict{String,Int}()
end

prog_cmd = JuliaProgram(
    name             = "Command Line",
    id_file          = ".common.cmd",
    inputs           = ["CMD" => Base.AbstractCmd],
    main             = main_cmd
)
