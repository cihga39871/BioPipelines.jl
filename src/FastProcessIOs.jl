module FastProcessIOs

export FastInputStream

mutable struct FastInputStream
    source::IO
    fill2::Bool  # true: buffer to read is 1, buffer to fill source is 2.
    buf1::Vector{UInt8}
    buf2::Vector{UInt8}
    pos1::Int  # Position of the next byte to be read in buffer;
    pos2::Int
    available1::Int  # Number of bytes available in buffer.
    available2::Int  # I.e. buf[pos:available] is valid data.
    lock::ReentrantLock    # lock when switch buf1 and buf2
    task_fill_source::Ref{Task}
end

const default_buffer_size = 2^24

function FastInputStream(source::T, bufsize::Integer = default_buffer_size) where T
    if bufsize < 2048
        bufsize = 2048
    end
    t = @async 1+1
    io = FastInputStream(source, eof(source), Vector{UInt8}(undef, bufsize), Vector{UInt8}(undef, bufsize), 1, 1, 0, 0, ReentrantLock(), Ref{Task}())
    io.task_fill_source[] = t
    wait(t)
    async_fill_buffer_from_source!(io::FastInputStream)
    io
end

"""
    async_fill_buffer_from_source!(io::FastInputStream)

Require lock, and fill backup buffer. No change to positions of current buffer.

This function runs asynchronously.
"""
function async_fill_buffer_from_source!(io::FastInputStream)
    eof(io.source) && (return false)
    lock(io.lock) do
        if istaskdone(io.task_fill_source[])
            if io.fill2 && io.available2 == 0
                io.task_fill_source[] = @async lock(io.lock) do 
                    io.available2 = readbytes!(io.source, io.buf2)
                    io.pos2 = 1
                end
            elseif !io.fill2 && io.available1 == 0
                io.task_fill_source[] = @async lock(io.lock) do 
                    io.available1 = readbytes!(io.source, io.buf1)
                    io.pos1 = 1
                end
            end
        end
    end
    true
end

"""
    switch(io::FastInputStream) -> Bool

Used only when current `buf[pos:available]` is copied!

Lock io, and switch current and backup. Old current pos and available will be set to 1 and 0. Then, asyncly fill old current buffer (ie. new backup buffer).

Return `true` if switch success, `false` if `eof(io)`.
"""
function switch(io::FastInputStream)
    lock(io.lock) do
        eof(io) && (return false)
        if io.fill2  # current=1, backup=2
            # current has been read through.
            # make backup as new current
            io.pos1 = 1
            io.available1 = 0
            io.fill2 = false
        else
            io.pos2 = 1
            io.available2 = 0
            io.fill2 = true
        end
        async_fill_buffer_from_source!(io)
    end
    return true
end

"""
    enlarge_buffer!(io::FastInputStream)

Return `false` if `eof(io)`.

Lock io, resize both buffers to double sizes. Append backup's available data to current data. Then, asyncly fill backup buffer from source.
"""
function enlarge_buffer!(io::FastInputStream)
    eof(io.source) && (return false)

    lock(io.lock)

    resize!(io.buf1, 2 * length(io.buf1))
    resize!(io.buf2, 2 * length(io.buf2))

    if io.fill2  # current=1, fill=2
        # copy fill to current
        n_copy = io.available2
        p_src = pointer(io.buf2)
        p_dest = pointer(io.buf1, io.available1 + 1)

        if length(io.buf1) < io.available1 + n_copy
            resize!(io.buf1, io.available1 + n_copy)
        end
        unsafe_copyto!(p_dest, p_src, n_copy)

        io.available1 += n_copy
        io.available2 = 0
        io.pos2 = 1
    else
        n_copy = io.available1
        p_src = pointer(io.buf1)
        p_dest = pointer(io.buf2, io.available2 + 1)

        if length(io.buf2) < io.available2 + n_copy
            resize!(io.buf2, io.available2 + n_copy)
        end
        unsafe_copyto!(p_dest, p_src, n_copy)

        io.available2 += n_copy
        io.available1 = 0
        io.pos1 = 1
    end
    unlock(io.lock)
    async_fill_buffer_from_source!(io)

    return true
end

Base.eof(io::FastInputStream) = io.pos1 > io.available1 && io.pos2 > io.available2 && eof(io.source)
Base.close(io::FastInputStream) = close(io.source)

function Base.readline(io::FastInputStream; keep::Bool = false)
    eof(io) && (return "")
    line_first = Ref{String}()

    @label start_of_readline

    if io.fill2  # current 1, backup 2
        buf = io.buf1
        pos = io.pos1
        available = io.available1
        buf_other = io.buf2
    else
        buf = io.buf2
        pos = io.pos2
        available = io.available2
        buf_other = io.buf1
    end

    stop = pos
    
    @label loop_to_find_char

    while stop <= available
        @inbounds if buf[stop] == 0x0a # '\n'
            line = String(buf[pos:(keep ? stop : stop - 1)])
            if io.fill2
                io.pos1 = stop + 1
            else
                io.pos2 = stop + 1
            end
            if isdefined(line_first, 1)
                return line_first[] * line
            else
                return line
            end
        end
        stop += 1
    end

    if !isdefined(line_first, 1)
        ## not found until readthrough buf[pos:available]
        # first part of string:
        line_first[] = String(buf[pos:available])

        # check buf_other
        wait(io.task_fill_source[])
        switched = switch(io)
        if switched
            # switch success 
            @goto start_of_readline
        else
            # eof(io)
            return line_first[]
        end
    
    else
        ## line_first is defined,
        ## so this is the second round through @label start_of_readline.
        ## Besides line_first[],
        ## current String(buf[pos:available]) is still used up.

        ## we need to enlarge the buffer.
        # Lock io, resize both buffers to double sizes. Append backup's available data to current data. Then, asyncly fill backup buffer from source.
        enlarged = enlarge_buffer!(io)
        if enlarged
            # buf, pos are the same
            # available is enlarged, so need refresh
            available = io.fill2 ? io.available1 : io.available2

            # stop are the same.
            @goto loop_to_find_char
        else
            # eof(io)
            line =  line_first[] * String(buf[pos:available])

            if io.fill2  # current 1, backup 2
                io.pos1 = io.available1 + 1
            else
                io.pos2 = io.available2 + 1
            end
            return line
        end
    end
end

end


#=

###### test below

bam = "/data/jc/analysis/archive/202304-possible-pw-ngs/polychrome_detector_pw/pcd-2-mapping-Rso/AWCA3_S3_L001_R1_001.atria.fastq.gz.bam"

bam = "/mnt/storage0/potato_cultivars/PRJNA378971_solanum_diversity_panel/2.map_to_potato/test/z.test.bam"

using .FastProcessIOs

io = FastInputStream(open(`samtools view -@ 10 -h $bam`))

io2 = open("$bam.data", "r")

n = 0
while !eof(io2) && !eof(io)
    n += 1
    x = readline(io)
    y = readline(io2)

    if x != y && !(x[1:3] == y[1:3] == "@PG")
        @show x y n
        break
    end
end

@assert eof(io)
@assert eof(io2)

close(io)
close(io2)



### test enlarge_buffer

io = FastInputStream(open(`samtools view -@ 10 -h $bam`), 8)

io2 = open("$bam.data", "r")

n = 0
while !eof(io2) && !eof(io)
    n += 1
    x = readline(io)
    y = readline(io2)
    if x != y  && !(x[1:3] == y[1:3] == "@PG")
        @show x y n
        break
    end
end

@assert eof(io)
@assert eof(io2)

close(io)
close(io2)


#### speed benchmark

io = FastInputStream(open(`samtools view -@ 10 -h $bam`))

io2 = open(`samtools view -@ 10 -h $bam`)

c = 0
@time while !eof(io)
    line = readline(io)
    c += length(line)
end
#   1.752296 seconds (4.09 M allocations: 863.047 MiB, 8.26% gc time)

c2 = 0
@time while !eof(io2)
    line = readline(io2)
    c2 += length(line)
end
#   2.250346 seconds (6.04 M allocations: 1.415 GiB, 13.29% gc time, 1.21% compilation time)

@assert c == c2

close(io)
close(io2)


=#