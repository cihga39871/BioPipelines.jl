_dep_bwa_mem2() = CmdDependency(
    exec = `$(Config.path_bwa_mem2)`,
    test_args = `mem`,
    validate_stderr = x -> occursin("bwa", x)
)

function check_bwa_mem2_index(bwa_reference::String)::Bool
    @debug "check_bwa_mem2_index(): $bwa_reference"

    # lock to prevent doing multiple index at the same time
    index_lock = bwa_reference * ".bwa_index_lock"  # lock should be the same as BWA 1.
    while isfile(index_lock)
        sleep(5)
    end

    has_bwa_index = isfile(bwa_reference) &&
                    isfile(bwa_reference * ".amb") &&
                    isfile(bwa_reference * ".ann") &&
                    isfile(bwa_reference * ".bwt.2bit.64") &&
                    isfile(bwa_reference * ".pac") &&
                    isfile(bwa_reference * ".0123")
    if has_bwa_index
        return true
    else
        @warn "check_bwa_mem2_index(): failed: no bwa-mem2 index found: $bwa_reference"
        return false
    end
end

function bwa_mem2_index(bwa_reference::String; bwa=dep_bwa_mem2)::String
    check_bwa_mem2_index(bwa_reference) && (return bwa_reference)

    # check file
    if !isfile(bwa_reference)
        error("bwa_mem2_index(): file not exist: $bwa_reference")
    end

    # lock to prevent doing multiple index at the same time
    index_lock = bwa_reference * ".bwa_index_lock"  # lock should be the same as BWA 1.
    touch(index_lock)

    # build bwa index
    @info "bwa_mem2_index(): building bwa mem 2 reference: $bwa_reference"
    try
        run(`$bwa index $bwa_reference`)
        rm(index_lock, force=true)
    catch e
        rm(index_lock, force=true)
        rethrow(e)
    end

    return bwa_reference
end

_prog_bwa_mem2() = CmdProgram(
    name             = "BWA-MEM2 Mapping",
    id_file          = ".mapping.bwa-mem2",
    cmd_dependencies = [dep_bwa_mem2, dep_samtools],
    inputs           = [
        "INDEX" => String,
        "READ1" => String,
        "READ2" => Union{String, Cmd} => ``,
        :THREADS => Int => 8,
        Symbol("THREADS-SAMTOOLS") => Int => 4,
        "OTHER-ARGS" => Cmd => Config.args_bwa_mem2
    ],
    validate_inputs  = i -> begin
        check_dependency_file(i["READ1"]) &&
        (isempty(i["READ2"]) || check_dependency_file(i["READ2"]))
    end,
    prerequisites    = (i,o) -> begin
        bwa_mem2_index(i["INDEX"], bwa=dep_bwa_mem2)
    end,
    cmd              = pipeline(
        `$dep_bwa_mem2 mem -t THREADS OTHER-ARGS INDEX READ1 READ2`,
        `$dep_julia $(Config.SCRIPTS["sam_correction"])`, # remove error lines genrated by bwa
        `$dep_samtools view -@ THREADS-SAMTOOLS -b -o BAM`
    ),
    infer_outputs    = do_nothing,
    outputs          = [
        "BAM" => String=> "<READ1>.bam"
    ],
    validate_outputs = o -> begin
        isfile(o["BAM"])
    end,
    wrap_up          = do_nothing
)
