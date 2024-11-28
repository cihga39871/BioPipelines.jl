#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Argument Error.\nUsage: Rscript <script.R> path_taxonomizr_dir\nDownload taxonomizr database to path_taxonomizr_dir/accessionTaxa.sql")
}

if (is.na(packageDescription("taxonomizr")[1])) install.packages("taxonomizr")

library(taxonomizr, quietly = T)

path_taxonomizr_dir <- args[1]

setwd(path_taxonomizr_dir)
prepareDatabase("accessionTaxa.sql", resume=TRUE)
