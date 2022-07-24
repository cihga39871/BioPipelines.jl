module GenomeClassification

using Pipelines
using ..Config

using ..Common

include("gtdbtk.jl")
export dep_gtdbtk, prog_gtdbtk_classify_wf, prog_gtdbtk_de_novo_wf

end
