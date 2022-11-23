_dep_kraken2() = CmdDependency(
    exec = `$(Config.path_kraken2)`,
    test_args = `--version`,
    validate_stdout = x -> occursin(r"version \d", x)
)

_prog_kraken2() = CmdProgram(
    name = "Kraken2",
    id_file = ".kraken2",
    cmd_dependencies = [dep_kraken2],
    inputs = [
        "INPUT_SEQ" => String,
        "DB" => String => Config.path_kraken2_db,
        :THREADS => Int => 1,
        "OTHER_ARGS" => Cmd => Config.args_kraken2
    ],
    outputs = [
        "UNCLASSIFIED_OUT" => String => "<INPUT_SEQ>.kraken2.unclassified.fa",
        "CLASSIFIED_OUT" => String => "<INPUT_SEQ>.kraken2.classified.fa",
        "OUTPUT" => String => "<INPUT_SEQ>.kraken2.out",
        "REPORT" => String => "<INPUT_SEQ>.kraken2.report"
    ],
    cmd = `$dep_kraken2 --db DB --threads THREADS --unclassified-out UNCLASSIFIED_OUT --classified-out CLASSIFIED_OUT --output OUTPUT --report REPORT OTHER_ARGS INPUT_SEQ`,
    arg_forward      = ["THREADS" => :ncpu]
)

const KRAKEN2_REPORT_HEADER = ["PctFragment", "NumFragment", "NumFragmentDirect", "RankCode", "TaxID", "ScientificName"]
const KRAKEN2_REPORT_HEADER_TYPES = [Float64, Int64, Int64, String, Int64, String]

"""
    kraken2_split_fasta_by_tax(kraken2_outputs::Dict; rank_code::String = "S", rank_pct::Real = 20)

- `kraken2_outputs::Dict`: output result of prog_kraken2.

- `rank_code::String = "S"`: select ranks .== RankCode. A rank code, indicating (U)nclassified, (R)oot, (D)omain, (K)ingdom, (P)hylum, (C)lass, (O)rder, (F)amily, (G)enus, or (S)pecies. Taxa that are not at any of these 10 ranks have a rank code that is formed by using the rank code of the closest ancestor rank with a number indicating the distance from that rank. E.g., "G2" is a rank code indicating a taxon is between genus and species and the grandparent taxon is at the genus rank.

- `rank_pct::Real = 20`: select ranks if percentage of fragments >= the value (0 to 100).

Return:

```julia
Dict{String, Any}:
    "REPORT_FILTERED" :: String => "/path/to/filtered/report.tsv"
    "CLASSIFIED_OUT_BY_TAX" :: Dict{String, String} => 
        "ScientificName" => "/path/to/fasta"
```

> More information on Kraken2 outputs: https://github.com/DerrickWood/kraken2/wiki/Manual#output-formats
"""
function kraken2_split_fasta_by_tax(kraken2_outputs::Dict; rank_code::String = "S", rank_pct::Real = 20)
    report_df = CSV.read(kraken2_outputs["REPORT"], DataFrame, delim='\t', header = KRAKEN2_REPORT_HEADER, types = KRAKEN2_REPORT_HEADER_TYPES, stripwhitespace = true)

    filter!(row -> 
        row.RankCode == rank_code && 
        row.PctFragment >= rank_pct && 
        row.NumFragmentDirect > 0,  # if == 0, empty fa will be generated
    report_df)

    out_report_filtered_path = kraken2_outputs["REPORT"] * ".filtered.tsv"
    CSV.write(out_report_filtered_path, report_df, delim = '\t')

    out_dict = Dict{String, Any}("REPORT_FILTERED" => out_report_filtered_path)
    if nrow(report_df) == 0
        out_dict["CLASSIFIED_OUT_BY_TAX"] = Dict{String,String}()
        return out_dict
    end

    out_fastas = _kraken2_split_fasta_by_tax(report_df, kraken2_outputs["CLASSIFIED_OUT"])
    out_dict["CLASSIFIED_OUT_BY_TAX"] = out_fastas
    out_dict
end

function _kraken2_split_fasta_by_tax(report_df::DataFrame, classified_fa::AbstractString)
    tax_2_io = Dict{Int, Any}()
    out_fa_dict = Dict{String, String}()
    for row in eachrow(report_df)
        name = replace(row.ScientificName, r"[^A-Za-z0-9]" => "_")
        file_name = replaceext(classified_fa, name * ".fa")
        io = FASTA.Writer(open(file_name, "w+"))
        tax_2_io[row.TaxID] = io
        out_fa_dict[row.ScientificName] = file_name
    end

    reader = open(FASTA.Reader, classified_fa)
    for record in reader
        tax_id_match = match(r"kraken\:taxid\|(\d+)", FASTA.description(record))
        isnothing(tax_id_match) && continue  # not kraken result, skip
        tax_id = parse(Int, tax_id_match.captures[1])

        io = get(tax_2_io, tax_id, nothing)
        isnothing(io) && continue  # no write for the tax id

        write(io, record)
    end

    for io in values(tax_2_io)
        close(io)
    end
    out_fa_dict
end