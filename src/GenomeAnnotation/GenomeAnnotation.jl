module GenomeAnnotation

using Pipelines
using ..Config

using ..Common

include("anvio.jl")
export dep_anvio, prog_anvio_annotation_wf

end
