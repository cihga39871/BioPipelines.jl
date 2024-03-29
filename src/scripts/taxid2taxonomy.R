#!Rscript

if (is.na(packageDescription("taxonomizr")[1])) install.packages("taxonomizr")
if (is.na(packageDescription("argparse")[1])) install.packages("argparse")
if (is.na(packageDescription("stringr")[1])) install.packages("stringr")

library(taxonomizr, quietly = T)
library(argparse, quietly = T)
library(stringr, quietly = T)

### parsing arguments
parser <- ArgumentParser(description='Input a table file which has an NCBI Accession column. Query taxonomy locally, and add the results to the table.')
parser$add_argument('-i', '--input', dest='input', metavar='FILE', type='character',
                    required=TRUE, nargs='+',
                    help='[REQUIRED] input tsv files generated by CLC BLAST module, or blastn (`blastn -outfmt 7`)')
parser$add_argument('-H', '--header', dest='header',
                    action='store_true',
                    help='does input has header?')
parser$add_argument('-t', '--tax-id-column', dest='tax-id-column', metavar='COL', type='integer',
                    default=5,
                    help='tax id column number')
parser$add_argument('-d', '--db', dest='db', metavar='db', type='character',
                    required=TRUE,
                    help='taxonomizr SQLite database')
parser$add_argument('-o', '--output', dest='output', metavar='TSV', type='character',
                    default="<input>.lineage.tsv",
                    help='output lineage file (default: <input>.lineage.tsv)')

args <- parser$parse_args()

db <- args$db
inputs <- args$input
tax_id_col <- args$`tax-id-column`
has_header <- args$header
for (input in inputs){
    
    out <- str_replace_all(args$output, "<input>", input)
    
    nline <- system(str_interp("grep -cv '^#' ${input}"), intern = TRUE)
    if (nline == "0") {
        # input is empty
        writeLines(str_interp("Taxid2Taxonomy: input is empty: ${input}"))
        system(str_interp("truncate --size=0 ${out}"))
        next
    }

    dt <- read.delim(input, header = has_header, comment.char = '#')

    ids <- dt[[tax_id_col]]
    taxs <- getTaxonomy(ids, db, desiredTaxa = c("superkingdom", "clade", "phylum", "class", "order", "family", "genus", "species", "subspecies", "strain"))
    dt <- cbind(dt, as.data.frame(taxs))
    write.table(dt, out, quote = F, sep = '\t', row.names = F)
    writeLines(str_interp("Taxid2Taxonomy: output: ${out}"))
}
