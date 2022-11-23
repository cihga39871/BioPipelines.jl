#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Argument Error.\nUsage: Rscript <script.R> path_taxonomizr_dir path_taxonomizr_db")
}

if (is.na(packageDescription("taxonomizr")[1])) install.packages("taxonomizr")

library(taxonomizr, quietly = T)

path_taxonomizr_dir <- args[1]
path_taxonomizr_db <- args[2]

setwd(path_taxonomizr_dir)
prepareDatabase(path_taxonomizr_db)
