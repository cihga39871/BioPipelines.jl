_dep_kma() = CmdDependency(
    exec = `$(Config.path_kma)`,
    test_args = `-v`,
    validate_stdout = x -> occursin(r"\d+\.\d+\.\d+", x)
)
_dep_ccmetagen() = CmdDependency(
    exec = `$(Config.path_ccmetagen)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"\d+\.\d+\.\d+", x)
)

_prog_kma_set_shared_memory() = CmdProgram(
    mod = @__MODULE__,
    name = "KMA - Mem",
    id_file = ".kma-shm",
    cmd_dependencies = [dep_kma],
    inputs = [
        "DB" => String => Config.path_kma_db,
        "LEVEL" => Int => 1
    ],
    cmd = `$dep_kma shm -t_db DB -shmLvl LEVEL`
)

_prog_kma_destory_shared_memory() = CmdProgram(
    mod = @__MODULE__,
    name = "KMA-",
    id_file = ".kma-shm-destory",
    cmd_dependencies = [dep_kma],
    inputs = [
        "DB" => String => Config.path_kma_db,
    ],
    cmd = `$dep_kma shm -t_db DB -destroy`
)


_prog_kma() = JuliaProgram(
    mod = @__MODULE__,
    name = "KMA",
    id_file = ".kma",
    cmd_dependencies = [dep_kma],
    inputs = [
        "INPUT_R1" => String,
        "INPUT_R2" => String => "",
        "DB" => String => Config.path_kma_db,
        :THREADS => Int => 1,
        "OTHER_ARGS" => Cmd => Config.args_kma
    ],
    outputs = [
        "OUT_PREF" => String => "<INPUT_R1>.kma",
    ],
    main = quote
        if INPUT_R2 == ""
            input_args = `-i $INPUT_R1`
        else
            input_args = `-ipe $INPUT_R1 $INPUT_R2 -apm f`
        end
        run(`$dep_kma $input_args -o $OUT_PREF -t_db $DB -t $THREADS $OTHER_ARGS`)
    end,
    validate_inputs = quote
        isfile(DB * ".comp.b") &&
        isfile(DB * ".length.b") &&
        isfile(DB * ".name") &&
        isfile(DB * ".seq.b") &&
        isfile(INPUT_R1) &&
        isfile(INPUT_R2)
    end,
    validate_outputs = quote
        res = OUT_PREF * ".res"
        isfile(res) && filesize(res) > 0
    end,
    arg_forward      = ["THREADS" => :ncpu]
)