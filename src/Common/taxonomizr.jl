function check_accession2taxonomy_db()
    if isfile(Config.path_taxonomizr_db)
        return abspath(Config.path_taxonomizr_db)
    else
        cmd_to_install = `$dep_julia -e 'using BioPipelines; BioPipelines.prepare_taxonomizr_db()'`
        error("Accession2Taxonomy (Taxonomizr) Database is not found. Please install the database using the command:\n\n    $cmd_to_install\n\nIt will download 6 GB data from NCBI and processed to a 65 GB database. To change the path of the database file, please add `path_taxonomizr_db = \"/path/to/accessionTaxa.sql\"` in the Config file: $(joinpath(homedir(), ".BioPipelines", "config.jl"))")
    end
end

"""
    prepare_taxonomizr_db()

To change the location of db file, please change `Config.path_taxonomizr_db`.
"""
function prepare_taxonomizr_db()
    path_taxonomizr_db = Config.path_taxonomizr_db
    path_taxonomizr_dir = dirname(path_taxonomizr_db)

    @rput path_taxonomizr_db path_taxonomizr_dir


    mkpath(path_taxonomizr_dir); mode=0o755)

    @info "Preparing Taxonomizr Database: It will download 6 GB data from NCBI and processed to a 65 GB database. Please be patient and use a fast connection. Files will be downloaded to $path_taxonomizr_dir. To change the path of the database file, please exit the program and add `path_taxonomizr_db = \"/path/to/accessionTaxa.sql\"` in the Config file: $(joinpath(homedir(), ".BioPipelines", "config.jl"))"

    R"""
    if (is.na(packageDescription("taxonomizr")[1])) install.packages("taxonomizr")

    library(taxonomizr, quietly = T)

    setwd(path_taxonomizr_dir)
    prepareDatabase(path_taxonomizr_db)
    """

end
