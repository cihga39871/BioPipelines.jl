dep_blastn = CmdDependency(
    exec = `$(Config.path_blastn)`,
    test_args = `-h`,
    validate_stdout = x -> occursin(r"Nucleotide-Nucleotide BLAST", x)
)

prog_blastn = CmdProgram(
    name             = "BLASTn",
    id_file          = ".common.blastn",
    cmd_dependencies = [dep_blastn],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_blastn ARGS`
)

dep_makeblastdb = CmdDependency(
    exec = `$(Config.path_makeblastdb)`,
    test_args = `-h`,
    validate_stdout = x -> occursin(r"Application to create BLAST databases", x)
)

prog_makeblastdb = CmdProgram(
    name             = "Make BLAST Database",
    id_file          = ".common.makeblastdb",
    cmd_dependencies = [dep_makeblastdb],
    inputs           = ["ARGS" => Cmd],
    cmd              = `$dep_makeblastdb ARGS`
)
