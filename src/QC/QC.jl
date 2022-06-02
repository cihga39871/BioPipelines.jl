module QC

using Pipelines
using ..Config
using DataFrames, DataFramesMeta, CSV, JSON  # QC/checkm

include("fastqc.jl")
export dep_fastqc, prog_fastqc

include("multiqc.jl")
export dep_multiqc

include("checkm.jl")
export dep_checkm, prog_checkm, prog_checkm_lineage_wf, prog_checkm_lineage_summary

end
