# Some useful utilities for dealing with flowing signals

using SoapySDR, Printf

"""
    stream_data(stream; buff_size)

Returns a `Channel` which will yield buffers of data to be processed.  Starts an asynchronous task
that does the reading from the stream, until the requested number of samples are read.
"""
function stream_data(s_rx::SoapySDR.Stream, num_samples::Integer;
                     buff_size::Integer = s_rx.mtu,
                     channel_capacity::Integer = 10,
                     leadin_samples::Integer = 16*buff_size)
    # We'll pre-allocate `channel_capacity + 1` buffers, pushing them onto the channel one after another, so that 
    # we can be certain that we'll never overwrite a buffer that has been previously sent out for processing.
    buffs = [Vector{ComplexF32}(undef, buff_size) for _ in 1:(channel_capacity+1)]
    c = Channel{Vector{ComplexF32}}(10)

    Base.errormonitor(Threads.@spawn begin
        SoapySDR.activate!(s_rx)
        # First, let the stream come online for a bit
        for _ in 1:ceil(Int, leadin_samples/buff_size)
            read!(s_rx, (buffs[1],); timeout=1u"s")
        end

        # Next, stream buffers until we read in the requested number of samples
        for buff_idx in 1:ceil(Int, num_samples/buff_size)
            # Read a buffer
            buff_idx = mod1(buff_idx, channel_capacity+1)
            read!(s_rx, (buffs[buff_idx],); timeout=1u"s")

            # Send it off for consumption
            put!(c, buffs[buff_idx])
        end
        SoapySDR.deactivate!(s_rx)

        # Close our channel once we're done.
        close(c)
    end)
    return c
end

function generate_test_pattern(num_samples::Int; buff_size::Int = 1024)
    c = Channel{Vector{ComplexF32}}(10)

    Base.errormonitor(Threads.@spawn begin
        buff = Vector{ComplexF32}(undef, buff_size)
        for idx in 1:num_samples
            buff_idx = mod1(idx, buff_size)
            buff[buff_idx] = ComplexF32(idx, idx)
            if buff_idx == buff_size
                put!(c, copy(buff))
            end
        end
        close(c)
    end)
    return c
end

"""
    consume_channel(f::Function, c::Channel, args...)

Consumes the given channel, calling `f(data, args...)` where `data` is what is
taken from the given channel.  Returns when the channel closes.
"""
function consume_channel(f::Function, c::Channel, args...)
    while !isempty(c) || isopen(c)
        local data
        try
            data = take!(c)
        catch e
            if isa(e, InvalidStateException)
                continue
            end
            rethrow(e)
        end
        f(data, args...)
    end
end

"""
    tee(in::Channel)

Returns two channels that synchronously output what comes in from `in`.
"""
function tee(in::Channel{T}) where {T}
    out1 = Channel{T}()
    out2 = Channel{T}()
    Base.errormonitor(Threads.@spawn begin
        consume_channel(in) do data
            put!(out1, data)
            put!(out2, data)
        end
        close(out1)
        close(out2)
    end)
    return (out1, out2)
end

"""
    rechunk(in::Channel, chunk_size::Int)

Converts a stream of chunks with size A to a stream of chunks with size B.
"""
function rechunk(in::Channel{Vector{T}}, chunk_size::Int) where {T}
    out = Channel()

    Base.errormonitor(Threads.@spawn begin
        chunk_filled = 0
        chunk_idx = 1
        # We'll alternate between filling up these three chunks, then sending
        # them down the channel.  We have three so that we can have:
        # - One that we're modifying,
        # - One that was sent out to a downstream,
        # - One that is being held by an intermediary
        chunks = [
            zeros(T, chunk_size),
            zeros(T, chunk_size),
            zeros(T, chunk_size),
        ]
        consume_channel(in) do data
            # Make the loop type-stable
            data = view(data, 1:length(data))

            # Generate chunks until this data is done
            while !isempty(data)
                # How many samples are we going to consume from this buffer?
                samples_wanted = (chunk_size - chunk_filled)
                samples_taken = min(length(data), samples_wanted)

                # Copy as much of `data` as we can into `chunks`
                chunks[chunk_idx][chunk_filled+1:chunk_filled + samples_taken] = data[1:samples_taken]
                chunk_filled += samples_taken

                # Move our view of `data` forward:
                data = view(data, samples_taken+1:length(data))

                # If we filled the chunk completely, then send it off and flip `chunk_idx`:
                if chunk_filled >= chunk_size
                    put!(out, chunks[chunk_idx])
                    chunk_idx = mod1(chunk_idx + 1, length(chunks))
                    chunk_filled = 0
                end
            end
        end
        close(out)
    end)

    return out
end

"""
    log_stream_xfer(in::Channel)

Logs messages summarizing our data transfer to stdout.
"""
function log_stream_xfer(in::Channel{Vector{T}}; print_period = 1.0, α = 0.7) where {T}
    out = Channel{Vector{T}}()
    Base.errormonitor(Threads.@spawn begin
        start_time = time()
        last_print = start_time
        samples_per_sec = 0.0
        last_buffers = 0
        buffers = 0
        consume_channel(in) do data
            buffers += 1
            curr_time = time()
            if curr_time - last_print > print_period
                samples_per_sec = (α * samples_per_sec + (1 - α) * (buffers - last_buffers) * length(data))
                @info("Xfer",
                    buffers,
                    buffer_size = length(data),
                    samples_per_sec = @sprintf("%.1f MHz", samples_per_sec/1e6),
                    data_rate = @sprintf("%.1f MB/s", samples_per_sec * sizeof(T)/1e6),
                    duration = @sprintf("%.1f s", curr_time - start_time),
                )
                last_print = curr_time
                last_buffers = buffers
            end

            put!(out, data)
        end
        close(out)
    end)
    return out
end
