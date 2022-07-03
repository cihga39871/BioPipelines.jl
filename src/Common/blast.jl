_dep_blastn() = CmdDependency(
    exec = `$(Config.path_blastn)`,
    test_args = `-h`,
    validate_stdout = x -> occursin(r"Nucleotide-Nucleotide BLAST", x)
)

_prog_blastn() = CmdProgram(
    name             = "BLASTn",
    id_file          = ".common.blastn",
    cmd_dependencies = [dep_blastn],
    inputs           = ["ARGS" => Cmd, :NTHREADS => Int => 1],
    validate_inputs = i -> begin
        if "-num_threads" in i["ARGS"].exec
            @error("prog_blastn: -num_threads detected in ARGS. Please move the argument out of ARGS and define it in Pipelines style inputs: NTHREADS")
            return false
        end
        return true
    end,
    cmd              = `$dep_blastn -num_threads NTHREADS ARGS`
)

_dep_makeblastdb() = CmdDependency(
    exec = `$(Config.path_makeblastdb)`,
    test_args = `-h`,
    validate_stdout = x -> occursin(r"Application to create BLAST databases", x)
)

_prog_makeblastdb() = CmdProgram(
    name             = "Make BLAST Database",
    id_file          = ".common.makeblastdb",
    cmd_dependencies = [dep_makeblastdb],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_makeblastdb ARGS`
)
