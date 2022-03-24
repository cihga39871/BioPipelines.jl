using Pkg
Pkg.activate(abspath(@__DIR__, "..", ".."))

include(abspath(@__DIR__, "..", "..", "config", "Config.jl"))
using .Config

using RCall

path_to_taxonomizr_db = Config.path_to_taxonomizr_db
path_to_taxonomizr_dir = dirname(path_to_taxonomizr_db)

@rput path_to_taxonomizr_db path_to_taxonomizr_dir


mkpath(path_to_taxonomizr_dir); mode=0o755)

@info "Preparing Taxonomizr Database: This is a big (several gigabytes) download and process. Please be patient and use a fast connection."

R"""
if (is.na(packageDescription("taxonomizr")[1])) install.packages("taxonomizr")

library(taxonomizr, quietly = T)

setwd(path_to_taxonomizr_dir)
prepareDatabase(path_to_taxonomizr_db)
"""
