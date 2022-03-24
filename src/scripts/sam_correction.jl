#!julia

# using Pkg
# Pkg.activate(abspath(@__DIR__, "..", ".."))

if "-h" in ARGS || "--help" in ARGS || length(ARGS) > 2
    println("""
    Usage:
        $(@__FILE__) SAM_FILE [SAM_OUT]
        script_to_out_sam | $(@__FILE__) | samtools view -b -o BAM_FILE

    Check whether sam files are good. Invalid records are removed. Compressed not supported.
    """)
    exit()
end


function sam_validation(sam; out::IO=stdout)
    @info "Sam Validation Start: $sam"
    if sam isa AbstractString
        io = open(sam, "r")
    elseif sam isa IO
        io = sam
    end

    line_num = 0
    while !eof(io)
        line = readline(io)
        line_num += 1

        if length(line) == 0 || line[1] == '@'
            println(out, line)
            continue
        end

        splitted = split(line, '\t')
        if length(splitted) < 11
            @error("Error in line $line_num of file $sam: column < 11:\n$line")
            continue
        end

        if length(splitted[10]) != length(splitted[11])
            @error("Error in line $line_num of file $sam: SEQ and QUAL of different length:\n$line")
            continue
        end

        println(out, line)
    end
    @info "Sam Validation Passed ($(line_num) lines): $sam"
end

if length(ARGS) == 0
    sam_validation(stdin)
elseif length(ARGS) == 1
    sam_validation(ARGS[1])
else
    out = open(ARGS[2], "w+")
    sam_validation(ARGS[1]; out = out)
    close(out)
end
