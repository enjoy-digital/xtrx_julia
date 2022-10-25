# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

using SoapySDR
using Test
using CUDA
using TimerOutputs

const to = TimerOutput()

# Bring this in just for un_sign_extend!()
using LibSigflow: un_sign_extend!

device!(0)  # SoapySDR needs CUDA to be initialized

#SoapySDR.register_log_handler()

function verify_lfsr_buffer(buff::AbstractArray{Complex{Int16}}, buff_idx::Int; show_mismatch::Bool = false)
    error_count = 0
    for j in eachindex(buff)
        # Ensure that the LFSR output has real/imaginary parts that are bit-flips of eachother
        re = UInt16(real(buff[j]))
        im = UInt16(imag(buff[j]))
        if re != (~im & 0x0fff)
            error_count += 1
            if show_mismatch
                @warn("LFSR bitflip failure", j, re, im, buff_idx)
            end
        end
    end
    return error_count
end

# Helper functions to do the FPGA's 24-bit counter <-> 24-bit I/Q tuple conversion
function counter_to_iq(counter::Integer)
    return Complex{Int16}(counter & 0xfff, (counter >> 12) & 0xfff)
end
function iq_to_counter(iq::Complex{<:Integer})
    return Int32(real(iq)) & 0xfff |
         ((Int32(imag(iq)) & 0xfff) << 12)
end

# State to track the FPGA pattern counter from buffer to buffer
const _counter = Ref{Int32}(0)
function verify_fpga_pattern_buffer(buff::AbstractArray{Complex{Int16}}, buff_idx::Int; show_mismatch::Bool = false, show_sync::Bool = true, step::Int = 1)
    counter = _counter[]
    error_count = 0

    # If we're not synchronized, then sync up and notify the user:
    if counter_to_iq(counter) != buff[1]
        if show_sync
            @info("FPGA pattern synchronizing", counter, iq_to_counter(buff[1]), counter_to_iq(counter), buff[1], buff_idx)
        end
        counter = iq_to_counter(buff[1])
        if buff_idx > 0
            error_count += 1
        end
    end

    # Sweep through and check all the other samples
    for idx in 1:step:length(buff)
        if buff[idx] != counter_to_iq(counter)
            if show_mismatch
                @warn("FPGA pattern skip", received=buff[idx], counter_to_iq(counter), buff_idx)
            end
            error_count += 1
        end
        counter = mod(counter + step, 2^24)
    end

    # Store our state
    _counter[] = counter
    return error_count
end

function verify_buffer(buff::AbstractArray{Complex{Int16}}, buff_idx::Int, lfsr_mode::Bool; show_mismatch::Bool = false, show_sync::Bool = true)
    # un-sign-extend since the soapysdr-xtrx is doing sign extension within itself
    un_sign_extend!(buff)

    if lfsr_mode
        return verify_lfsr_buffer(buff, buff_idx; show_mismatch)
    else
        return verify_fpga_pattern_buffer(buff, buff_idx; show_mismatch, show_sync)
    end
end

function dma_test(dev_args;use_gpu=false, lfsr_mode=false, show_mismatch=false)
    # GPU: set the DMA target
    dma_mode = use_gpu ? "GPU" : "CPU"
    dev_args["device"] = dma_mode

    Device(dev_args) do dev
        # get the RX channel
        chan = dev.rx[1]

        #SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "")

        if lfsr_mode
            SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "")
            SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE_LFSR", "TRUE")
            SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "")
        else
            SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE_LFSR", "FALSE")
            SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "")
            SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_PATTERN", "1")
            SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")
        end

        #SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "")

        # NOTE: we use the LMS7002M's loopback to validate the entire chain,
        #       but this also works with the FPGA's loopback

        # open RX stream
        stream = SoapySDR.Stream([chan])
        mtu = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream)
        num_channels = Int(length(dev.rx))

        wr_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream)
        @info "Number of DMA buffers: $wr_nbufs"
        @info "MTU: $mtu"
        if use_gpu
            @info "Using GPU"
        else
            @info "Using CPU"
        end

        # acquire buffers using the low-level API
        buffs = Ptr{Complex{Int16}}[C_NULL]
        total_bytes = 0
        error_count = 0
        errored_buffer_count = 0
        total_buffer_count = 0
        overflow_events = 0

        # When running on GPU, we need to copy over to CPU for verification
        cpu_buff = Vector{Complex{Int16}}(undef, mtu*num_channels)

        @info "Receiving data using $dma_mode with $(lfsr_mode ? "LFSR" : "pattern")..."
        SoapySDR.activate!(stream) do
            time = @elapsed for i in 1:5000
                @timeit to "acquire" err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream, buffs)
                if err == SoapySDR.SOAPY_SDR_OVERFLOW
                    overflow_events += 1
                    continue
                elseif err == SoapySDR.SOAPY_SDR_TIMEOUT
                    continue
                end

                # uncomment to dump the DMA buffer states
                #if i%32 == 0
                    #println(unsafe_string(SoapySDR.SoapySDRDevice_readSetting(dev, "DMA_BUFFERS")))
                #end

                prev_error_count = error_count
                @timeit to "data validation" if use_gpu
                    # GPU NOTE:
                    # this is very tight with our 8K buffers: a kernel launch +
                    # 8K broadcast + sync takes ~10, while at a data rate of 1Gbps we
                    # can only spend ~60us per buffer. we'll need to use larger buffers,
                    # but that requires a larger BAR size and thus Above 4G decoding.
                    #
                    # we also shouldn't wait for the GPU to finish processing the data,
                    # but that requires more careful design that's out of scope here.

                    # copy the array over to the CPU for validation
                    copyto!(cpu_buff, unsafe_wrap(CuArray{Complex{Int16}, 1}, reinterpret(CuPtr{Complex{Int16}}, buffs[1]), Int(length(cpu_buff))))

                    error_count += verify_buffer(cpu_buff, total_buffer_count, lfsr_mode)
                    synchronize()   # data without running into overflows
                else
                    buff = unsafe_wrap(Array{Complex{Int16}}, buffs[1], Int(mtu*num_channels))
                    error_count += verify_buffer(buff, total_buffer_count, lfsr_mode)
                end

                if prev_error_count != error_count
                    errored_buffer_count = errored_buffer_count + 1
                end

                @timeit to "release" SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
                total_bytes += mtu*num_channels*sizeof(Complex{Int16})
                total_buffer_count += 1
            end
            show(to)
            println()
            reset_timer!(to)
            @info "Data rate: $(Base.format_bytes(total_bytes / time))/s"
            @info "Overflow events: $overflow_events"
            if error_count > 0
                @warn "Errored buffer count: ($errored_buffer_count/$total_buffer_count)"
                @warn "Total error count: $error_count"
            end
        end
    end
end

function main()
    for dev_args in Devices(driver="XTRX")
        GC.enable(false)
        try
            dma_test(dev_args; use_gpu=false, lfsr_mode=true)
            dma_test(dev_args; use_gpu=false, lfsr_mode=false)
            dma_test(dev_args; use_gpu=true,  lfsr_mode=true)
            dma_test(dev_args; use_gpu=true,  lfsr_mode=false)
        catch e
            @error "Test failed" path=dev_args["path"] serial=dev_args["serial"] exception=(e, catch_backtrace())
        end
    end
end

isinteractive() || main()
