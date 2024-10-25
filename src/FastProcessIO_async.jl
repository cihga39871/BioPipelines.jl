module FastProcessIOs

export FastInputStream

#TODO no copyto between two buffers

mutable struct FastInputStream
    source::IO

    buf::Vector{UInt8}
    buf_backup::Vector{UInt8}
    
    # Position of the next byte to be read in buffer;
    # `position < 0` indicates that the stream is closed.
    pos::Int

    # Number of bytes available in buffer.
    # I.e. buf[pos:available] is valid data.
    available::Int

    # Number of bytes available in the other buffer.
    # I.e. buf_backup[1:available] is valid data.
    available_backup::Int

    lock::ReentrantLock
    task_fill_backup::Ref{Task}
end

const default_buffer_size = 2^24

function FastInputStream(source::T, bufsize::Integer = default_buffer_size) where T
    if bufsize < 2048
        bufsize = 2048
    end
    t = @async 1+1
    io = FastInputStream(source, Vector{UInt8}(undef, bufsize), Vector{UInt8}(undef, bufsize), 1, 0, 0, ReentrantLock(), Ref{Task}())
    io.task_fill_backup[] = t
    wait(t)
    fill_buffer!(io::FastInputStream)
    io
end

"""
    fill_backup_buffer!(io::FastInputStream)

Require lock, and fill backup buffer only when `io.available_backup == 0` and `!eof(io.source)`.

This function runs asynchronously.

`io.pos` and `io.available` are not changed.
"""
function fill_backup_buffer!(io::FastInputStream)
    eof(io.source) && (return 0)
    lock(io.lock) do
        if istaskdone(io.task_fill_backup[])
            io.task_fill_backup[] = @async lock(io.lock) do
                if io.available_backup == 0
                    io.available_backup = readbytes!(io.source, io.buf_backup)
                else
                    0
                end
            end
        end
    end
end

"""
    buffer_transfer!(io::FastInputStream)

Lock io, enlarge `io.buf` when needed, append buf_backup to buf.

`io.pos` does not affect, and `io.available` is greater.
"""
function buffer_transfer!(io::FastInputStream)

    lock(io.lock) do 
        if isdefined(io.task_fill_backup, 1)
            wait(io.task_fill_backup[])
        end
        io.available_backup == 0 && (return 0)

        available_after = io.available + io.available_backup
        if available_after > length(io.buf)
            resize!(io.buf, available_after)
        end
        # copy buffer
        p_src = pointer(io.buf_backup)
        p_dest = pointer(io.buf, io.available + 1)
        unsafe_copyto!(p_dest, p_src, io.available_backup)
        io.available = available_after
        io.available_backup = 0
    end
end

"""
    fill_buffer!(io::FastInputStream)

Will update `io.pos` and `io.available`.
"""
function fill_buffer!(io::FastInputStream)
    lock(io.lock)
    # wait(io.task_fill_backup[])
    if eof(io.source) && io.available_backup == 0
        return 0
    end

    if io.pos == 1 && io.available == length(io.buf)
        return 0
    end
    n_copy = io.available - io.pos + 1

    if n_copy > 0
        ### move io.buf[pos:available] to io.buf[1:n_copy]
        p_src = pointer(io.buf, io.pos)
        p_dest = pointer(io.buf)
        unsafe_copyto!(p_dest, p_src, n_copy)

    end

    # update positions
    io.pos = 1
    io.available = n_copy

    if io.available_backup == 0
        # buf_backup is empty, directly read to buf
        p_read = pointer(io.buf, io.available + 1)
        read_len = length(io.buf) - io.available
        buf_remain = unsafe_wrap(Vector{UInt8}, p_read, read_len)
        n_read = readbytes!(io.source, buf_remain)

        io.available += n_read
        unlock(io.lock)
    else
        # copy buf_backup to buf
        n_read = buffer_transfer!(io)
        unlock(io.lock)

        fill_backup_buffer!(io)  # async, require lock
    end
    return io.available
end

function enlarge_buffer!(io::FastInputStream)
    eof(io.source) && (return 0)

    lock(io.lock)

    resize!(io.buf, 2 * length(io.buf))
    resize!(io.buf_backup, 2 * length(io.buf_backup))

    if io.available_backup == 0
        # buf_backup is empty, directly read to buf
        p_read = pointer(io.buf, io.available + 1)
        read_len = length(io.buf) - io.available
        buf_remain = unsafe_wrap(Vector{UInt8}, p_read, read_len)
        n_read = readbytes!(io.source, buf_remain)
        io.available += n_read
        unlock(io.lock)
    
    else
        # copy buf_backup to buf
        n_read = buffer_transfer!(io)
        unlock(io.lock)

        fill_backup_buffer!(io)  # async, require lock
    end

    if eof(io.source)
        resize!(io.buf, io.available)
        resize!(io.buf_backup, 0)
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
        @label return_line
        if keep
            line = String(io.buf[io.pos:stop])
        else
            line = String(io.buf[io.pos:stop - 1])
        end
        io.pos = stop + 1

        return line
    else
        stop = io.available - io.pos + 2  # stop -1 is already checked
        n_read = fill_buffer!(io)
        if stop <= io.available
            @goto start_of_readline
        end

        # already read through but not found \n

        # whether buffer is full?
        if io.pos == 1 && io.available == length(io.buf)
            # buffer is full

            n_read = enlarge_buffer!(io)
            
            @goto start_of_readline
        else  # buffer is not full
            @goto return_line
        end
    end

end


end


#=
using .FastProcessIOs

io = FastInputStream(open(`samtools view -@ 10 -h /data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam`))

io2 = open("/data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam.data", "r")

n = 0
while !eof(io2) && !eof(io)
    n += 1
    x = readline(io)
    y = readline(io2)

    if x != y && x[1:3] != y[1:3]
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
#   2.700939 seconds (48.90 M allocations: 4.717 GiB, 3.17% gc time)

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