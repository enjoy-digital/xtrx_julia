# Some useful utilities for dealing with flowing signals

using SoapySDR, Printf, DSP, FFTW, Statistics

# Helper for turning a matrix into a tuple of views, for use with the SoapySDR API.
split_matrix(m::AbstractArray{T,2}) where {T} = tuple(collect(view(m, :, idx) for idx in 1:size(m,2))...)

_default_verbosity = false
function set_libsigflow_verbose(verbose::Bool)
    global _default_verbosity = verbose
end

"""
    generate_stream(gen_buff!::Function, buff_size, num_channels)

Returns a `Channel` that allows multiple buffers to be 
"""
function generate_stream(gen_buff!::Function, buff_size::Integer, num_channels::Integer;
                         wrapper::Function = (f) -> f(),
                         buffers_in_flight::Integer = 1,
                         T = ComplexF32)
    c = Channel{Matrix{T}}(buffers_in_flight)

    Base.errormonitor(Threads.@spawn begin
        buff_idx = 1
        try
            wrapper() do
                buff = Matrix{T}(undef, buff_size, num_channels)

                # Keep on generating buffers until `gen_buff!()` returns `false`.
                while gen_buff!(buff)
                    put!(c, copy(buff))
                end
                # Put the last one too
                put!(c, buff)
            end
        finally
            close(c)
        end
    end)
    return c
end
function generate_stream(f::Function, s::SoapySDR.Stream; kwargs...)
    return generate_stream(f, s.mtu, s.nchannels; kwargs...)
end

"""
    stream_data(s_rx::SoapySDR.Stream, num_samples::Integer)

Returns a `Channel` which will yield buffers of data to be processed of size `s_rx.mtu`.
Starts an asynchronous task that does the reading from the stream, until the requested
number of samples are read.
"""
function stream_data(s_rx::SoapySDR.Stream, num_samples::Integer;
                     leadin_buffers::Integer = 16,
                     kwargs...)
    # Wrapper to activate/deactivate `s_rx`
    wrapper = (f) -> begin
        SoapySDR.activate!(s_rx) do
            # Let the stream come online for a bit
            buff = Matrix{ComplexF32}(undef, s_rx.mtu, s_rx.nchannels)
            for _ in 1:leadin_buffers
                read!(s_rx, split_matrix(buff); timeout=1u"s")
            end

            # Invoke the rest of `generate_stream()`
            f()
        end
    end

    # Read streams until we exhaust the number of buffs
    buff_idx = 0
    return generate_stream(s_rx.mtu, s_rx.nchannels; wrapper, kwargs...) do buff
        read!(s_rx, split_matrix(buff); timeout=1u"s")
        buff_idx += 1
        return buff_idx*s_rx.mtu < num_samples
    end
end

"""
    stream_data(s_tx, in::Channel)

Feed data from a `Channel` out onto the airwaves via a given `SoapySDR.Stream`.
We suggest using `rechunk()` to convert to `s_tx.mtu`-sized buffers for maximum
efficiency.
"""
function stream_data(s_tx::SoapySDR.Stream, in::Channel{Matrix{ComplexF32}})
    Base.errormonitor(Threads.@spawn begin
        SoapySDR.activate!(s_tx) do
            # Consume channel and spit out into `s_tx`
            consume_channel(in) do data
                write(s_tx, split_matrix(data); timeout=0.1u"s")
            end

            # We need to `sleep()` until we're done transmitting,
            # otherwise we `deactivate!()` a little bit too eagerly.
            # Let's just assume we never transmit more than 1s at a time, for now.
            sleep(1)
        end
    end)
end

"""
    generate_test_pattern(pattern_len; num_channels = 1, num_buffers = 1)

Generate a test pattern, used in our test suite.  Always generates buffers with
length equal to `pattern_len`, if you need to change that, use `rechunk`.
Transmits `num_buffers` and then quits.
"""
function generate_test_pattern(pattern_len::Integer; num_channels::Int = 1, num_buffers::Integer = 1)
    buffs_sent = 0
    return generate_stream(pattern_len, num_channels) do buff
        for idx in 1:pattern_len
            buff[idx, :] .= ComplexF32(idx, idx)
        end
        buffs_sent += 1
        return buffs_sent < num_buffers
    end
end

"""
    generate_chirp(chirp_len; num_channels = 1, num_buffers = 1)

Generate a linear chirp from 0 -> fs/2 over `chirp_len` samples.
Always generates buffers with length equal to `chirp_len`, if you need to
change that, use `rechunk`.  Transmits `num_buffers` and then quits.
"""
function generate_chirp(chirp_len::Integer; num_channels::Integer = 1, num_buffers::Integer = 1)
    buffs_sent = 0
    return generate_stream(chirp_len, num_channels) do buff
        for idx in 1:chirp_len
            buff[idx, :] .= sin(idx.^2 * π / (2*chirp_len))
        end
        buffs_sent += 1
        return buffs_sent < num_buffers
    end
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
function rechunk(in::Channel{Matrix{T}}, chunk_size::Integer) where {T}
    out = Channel{Matrix{T}}()

    Base.errormonitor(Threads.@spawn begin
        chunk_filled = 0
        chunk_idx = 1
        # We'll alternate between filling up these three chunks, then sending
        # them down the channel.  We have three so that we can have:
        # - One that we're modifying,
        # - One that was sent out to a downstream,
        # - One that is being held by an intermediary
        chunks = [
            Matrix{T}(undef, 0, 0),
            Matrix{T}(undef, 0, 0),
            Matrix{T}(undef, 0, 0),
        ]
        function make_chunks!(num_channels)
            if size(chunks[1], 2) != num_channels
                for idx in eachindex(chunks)
                    chunks[idx] = Matrix{T}(undef, chunk_size, num_channels)
                end
                global chunk_filled = 0
                global chunk_idx = 1
            end
        end
        consume_channel(in) do data
            # Make the loop type-stable
            data = view(data, 1:size(data, 1), :)

            # Generate chunks until this data is done
            while !isempty(data)
                make_chunks!(size(data, 2))

                # How many samples are we going to consume from this buffer?
                samples_wanted = (chunk_size - chunk_filled)
                samples_taken = min(size(data, 1), samples_wanted)

                # Copy as much of `data` as we can into `chunks`
                chunks[chunk_idx][chunk_filled+1:chunk_filled + samples_taken, :] = data[1:samples_taken, :]
                chunk_filled += samples_taken

                # Move our view of `data` forward:
                data = view(data, samples_taken+1:size(data, 1), :)

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
    stft(in::Channel)

Stream an FFT of the buffers coming in on `Channel`.  Use `rechunk()` on the
input to force a time window size.  Combine with `reduce` to perform
grouping/reductions across time.
"""
function stft(in::Channel{Matrix{T}};
              window_function::Function = DSP.hanning) where {T}
    out = Channel{Matrix{T}}()
    BUFFS = [
        Matrix{T}(undef, 1, 1),
        Matrix{T}(undef, 1, 1),
    ]
    fft_plan = FFTW.plan_fft(BUFFS[1])
    win = T.([0])
    function make_BUFF!(buff)
        if size(BUFFS[1]) != size(buff)
            BUFFS = [
                Matrix{T}(undef, size(buff)...),
                Matrix{T}(undef, size(buff)...),
            ]
            fft_plan = FFTW.plan_fft(BUFFS[1], 1)
            win = T.(window_function(size(buff, 1)))
        end
    end
    
    Base.errormonitor(Threads.@spawn begin
        buff_idx = 1
        consume_channel(in) do buff
            # Prepare our lazyily-initialized memory/planning structures
            make_BUFF!(buff)

            # Perform the frequency transform
            FFTW.mul!(BUFFS[buff_idx], fft_plan, buff .* win)
            put!(out, BUFFS[buff_idx])
            buff_idx = mod1(buff_idx + 1, length(BUFFS))
        end
        close(out)
    end)
    return out
end

function absshift(in::Channel{Matrix{T}}) where {T}
    out = Channel{Matrix{Float32}}()

    Base.errormonitor(Threads.@spawn begin
        consume_channel(in) do buff
            val = FFTW.fftshift(Float32.(abs.(buff)))
            put!(out, val)
        end
        close(out)
    end)
    return out
end

"""
    reduce(reductor::Function, in::Channel, reduction_factor::Integer)

Buffers `reduction_factor` buffers together into a vector, then calls
`reductor(buffs)`, pushing the result out onto a `Channel`.
"""
function Base.reduce(reductor::Function, in::Channel{Matrix{T}}, reduction_factor::Integer; verbose::Bool = _default_verbosity) where {T}
    out = Channel{Matrix}()
    Base.errormonitor(Threads.@spawn begin
        buff_idx = 1
        acc = Array{T,3}(undef, 0, 0, 0)
        function make_acc!(buff)
            if size(acc,1) != size(buff, 1) || size(acc,2) != size(buff,2)
                if verbose
                    @info("make_acc!", buff_size=size(buff), acc_size=size(acc))
                end
                acc = Array{T,3}(undef, size(buff,1), size(buff,2), reduction_factor)
            end
        end
        consume_channel(in) do buff
            make_acc!(buff)
            acc[:, :, buff_idx] .= buff
            buff_idx += 1
            if buff_idx > reduction_factor
                put!(out, reductor(acc))
                buff_idx = 1
            end
        end
        close(out)
    end)
    return out
end

function collect_psd(in::Channel{Matrix{T}}, freq_size::Integer, buff_size::Integer; accumulation = :max) where {T}
    # Precaculate our reduction parameters
    reduction_factor = div(buff_size, freq_size)
    if accumulation == :max
        reductor = buffs -> maximum(buffs, dims=3)[:, :, 1]
    elseif accumulation == :mean
        reductor = buffs -> mean(buffs, dims=3)[:, :, 1]
    else
        throw(ArgumentError("Invalid accumulation algorithm '$(accumulation)'"))
    end

    # Reduce the absolute value, fft-shifted, STFT'ed input
    reduced = reduce(reductor,
        absshift(stft(rechunk(in, freq_size))),
        reduction_factor,
    )

    # We'll store our PSD frames here, then concatenate into a giant matrix later
    psd_frames = Matrix{Float32}[]
    consume_channel(reduced) do buff
        push!(psd_frames, buff[:, :])
    end
    return permutedims(cat(psd_frames..., dims=3), (1,3,2))
end

"""
    log_stream_xfer(in::Channel)

Logs messages summarizing our data transfer to stdout.
"""
function log_stream_xfer(in::Channel{Matrix{T}}; title = "Xfer", print_period = 1.0, α = 0.7) where {T}
    out = Channel{Matrix{T}}()
    Base.errormonitor(Threads.@spawn begin
        start_time = time()
        last_print = start_time
        total_samples = 0
        buffers = 0
        consume_channel(in) do data
            buffers += 1
            total_samples += prod(size(data))

            curr_time = time()
            if curr_time - last_print > print_period
                duration = curr_time - start_time
                samples_per_sec = total_samples/duration
                @info(title,
                    buffers,
                    buffer_size = size(data),
                    total_samples,
                    samples_per_sec = @sprintf("%.1f MHz", samples_per_sec/1e6),
                    data_rate = @sprintf("%.1f MB/s", samples_per_sec * sizeof(T)/1e6),
                    duration = @sprintf("%.1f s", duration),
                )
                last_print = curr_time
            end
            put!(out, data)
        end
        duration = time() - start_time
        samples_per_sec = total_samples/duration
        @info("$(title) - DONE",
            buffers,
            total_samples,
            samples_per_sec = @sprintf("%.1f MHz", samples_per_sec/1e6),
            data_rate = @sprintf("%.1f MB/s", samples_per_sec * sizeof(T)/1e6),
            duration = @sprintf("%.1f s", duration),
        )
        close(out)
    end)
    return out
end

"""
    flowgate(in::Channel, ctl::Base.Event)

Waits upon `ctl` before passing buffers through; useful for synchronization.
"""
function flowgate(in::Channel{Matrix{T}}, ctl::Base.Event;
                  name::String = "flowgate", verbose::Bool = _default_verbosity) where {T}
    out = Channel{Matrix{T}}()
    Base.errormonitor(Threads.@spawn begin
        already_printed = false
        consume_channel(in) do buff
            wait(ctl)
            if verbose && !already_printed
                @info("$(name) triggered", time=time())
                already_printed = true
            end
            put!(out, buff)
        end
        close(out)
    end)
    return out
end

"""
    tripwire(in::Channel, ctl::Base.Event)

Notifies `ctl` when a buffer passes through.
"""
function tripwire(in::Channel{Matrix{T}}, ctl::Base.Event;
                  name::String = "tripwire", verbose::Bool = _default_verbosity) where {T}
    out = Channel{Matrix{T}}()
    Base.errormonitor(Threads.@spawn begin
        already_printed = false
        consume_channel(in) do buff
            notify(ctl)
            if verbose && !already_printed
                @info("$(name) triggered", time=time())
                already_printed = true
            end
            put!(out, buff)
        end
        close(out)
    end)
    return out
end


function sign_extend!(x::AbstractArray{Complex{Int16}})
    xi = reinterpret(Int16, x)
    for idx in 1:length(xi)
        if xi[idx] >= (1 << 11)
            xi[idx] -= (1 << 12)
        end
    end
    return x
end
