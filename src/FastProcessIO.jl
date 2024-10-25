module FastProcessIOs

export FastInputStream

mutable struct FastInputStream
    source::IO
    buf::Vector{UInt8}
    
    # Position of the next byte to be read in buffer;
    # `position < 0` indicates that the stream is closed.
    pos::Int

    # Number of bytes available in buffer.
    # I.e. buf[1:available] is valid data.
    available::Int
end

const default_buffer_size = 2^24

function FastInputStream(source::T, bufsize::Integer = default_buffer_size) where T
    FastInputStream(source, Vector{UInt8}(undef, bufsize), 1, 0)
end

function fill_buffer!(io::FastInputStream)
    eof(io.source) && (return 0)

    n_copy = io.available - io.pos + 1

    if n_copy == 0
        io.available = readbytes!(io.source, io.buf)
        io.pos = 1
        return io.available
    end

    # need copy
    p_src = pointer(io.buf, io.pos)
    p_dest = pointer(io.buf)
    unsafe_copyto!(p_dest, p_src, n_copy)

    io.pos = 1
    io.available = n_copy

    p_read = pointer(io.buf, io.available + 1)
    read_len = length(io.buf) - io.available
    buf_remain = unsafe_wrap(Vector{UInt8}, p_read, read_len)
    n_read = readbytes!(io.source, buf_remain)

    io.available += n_read
end

function enlarge_buffer!(io::FastInputStream)
    eof(io.source) && (return 0)

    resize!(io.buf, 2 * length(io.buf))

    p_read = pointer(io.buf, io.available + 1)
    read_len = length(io.buf) - io.available
    buf_remain = unsafe_wrap(Vector{UInt8}, p_read, read_len)
    n_read = readbytes!(io.source, buf_remain)
    io.available += n_read

    if eof(io.source)
        resize!(io.buf, io.available)
    end
    io.available
end

Base.eof(io::FastInputStream) = io.pos > io.available && eof(io.source)
Base.close(io::FastInputStream) = close(io.source)

function Base.readline(io::FastInputStream; keep::Bool = false)
    stop = io.pos

    @label start_of_readline

    found_eol = false
    while stop <= io.available
        @inbounds if io.buf[stop] == 0x0a # '\n'
            found_eol = true
            break
        end
        stop += 1
    end

    if found_eol
        if keep
            line = String(io.buf[io.pos:stop])
        else
            line = String(io.buf[io.pos:stop - 1])
        end
        io.pos = stop + 1
        return line
    
    elseif eof(io.source)
        line = String(io.buf[io.pos:io.available])
        io.pos = io.available + 1
        return line

    else  # not found \n, still can read from io
        # whether buffer is full?
        if io.pos == 1 && io.available == length(io.buf)
            # buffer is full

            stop = io.available + 1
            n_avail = enlarge_buffer!(io)
            @assert n_avail != 0
            @goto start_of_readline
        else
            # buffer is not full, fill buffer
            stop = io.available - io.pos + 2  # stop -1 is already checked
            n_avail = fill_buffer!(io)
            @assert n_avail != 0
            @goto start_of_readline
        end
        @error "Bug: please report this bug. "
    end

end


end


#=
using .FastProcessIOs

io = FastInputStream(open(`samtools view -@ 10 -h /data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam`))

io2 = open(`samtools view -@ 10 -h /data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam`)

n = 0
while !eof(io2) && !eof(io)
    n += 1
    x = readline(io)
    y = readline(io2)
    if x != y
        @show x y n
        break
    end
end

@assert eof(io)
@assert eof(io2)

close(io)
close(io2)



### test enlarge_buffer

io = FastInputStream(open(`samtools view -@ 10 -h /data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam`), 8)

io2 = open(`samtools view -@ 10 -h /data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam`)

n = 0
while !eof(io2) && !eof(io)
    n += 1
    x = readline(io)
    y = readline(io2)
    if x != y
        @show x y n
        break
    end
end

@assert eof(io)
@assert eof(io2)

close(io)
close(io2)


#### speed benchmark

io = FastInputStream(open(`samtools view -@ 10 -h /data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam`), 8)

io2 = open(`samtools view -@ 10 -h /data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam`)

c = 0
@time while !eof(io)
    line = readline(io)
    c += length(line)
end
#   2.987756 seconds (53.33 M allocations: 4.784 GiB, 6.73% gc time)

c2 = 0
@time while !eof(io2)
    line = readline(io2)
    c2 += length(line)
end
#  24.543741 seconds (79.76 M allocations: 5.804 GiB, 1.73% gc time)

@assert c == c2

close(io)
close(io2)


=#