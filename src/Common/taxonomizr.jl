function check_accession2taxonomy_db()
    if isfile(Config.path_taxonomizr_db)
        return abspath(Config.path_taxonomizr_db)
    else
        cmd_to_install = `$dep_julia $(Config.SCRIPTS["prepare_taxonomizr_db"])`
        error("Accession2Taxonomy Database is not found. Please install the database using the command:\n\n    $cmd_to_install\n\nIt will download 6 GB data from NCBI and processed to a 65 GB database. To change the path of the database file, please add `path_taxonomizr_db = \"/path/to/accessionTaxa.sql\"` in the Config file: $(joinpath(homedir(), ".BioPipelinesConfig.jl"))")
    end
end
