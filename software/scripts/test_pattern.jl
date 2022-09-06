# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

using SoapySDR
using Test
using CUDA

#SoapySDR.register_log_handler()


function dma_test(dev_args;use_gpu=false, lfsr_mode=false)

    # GPU: set the DMA target
    dma_mode = use_gpu ? "GPU" : "CPU"
    dev_args["device"] = dma_mode

    Device(dev_args) do dev
        # get the RX channel
        chan = dev.rx[1]

        lfsr_mode && use_gpu && error("LFSR test mode cannot be verified with GPU")

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
        stream = SoapySDR.Stream(ComplexF32, [chan])

        mtu = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream)
        num_channels = Int(length(dev.tx))

        wr_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream)
        @info "Number of DMA buffers: $wr_nbufs"
        @info "MTU: $mtu"

        if use_gpu
            @info "Using GPU"
        else
            @info "Using CPU"
        end

        # acquire buffers using the low-level API
        buffs = Ptr{UInt32}[C_NULL]
        bytes = mtu*4
        total_bytes = 0

        prior_pointer = Ptr{UInt32}(0)
        counter = Int32(0)

        comp = Vector{Complex{Int16}}(undef, mtu*num_channels)

        overflow_events = 0

        initialized_count = false

        test_mode = lfsr_mode ? "LFSR" : "pattern"

        @info "Receiving data using $dma_mode with $test_mode..."
        SoapySDR.activate!(stream) do
            time = @elapsed for i in 1:600
                err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream, buffs)
                if err == SoapySDR.SOAPY_SDR_OVERFLOW
                    overflow_events += 1
                elseif err == SoapySDR.SOAPY_SDR_TIMEOUT
                    SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
                    continue
                end

                if use_gpu
                    # GPU NOTE:
                    # this is very tight with our 8K buffers: a kernel launch +
                    # 8K broadcast + sync takes ~10, while at a data rate of 1Gbps we
                    # can only spend ~60us per buffer. we'll need to use larger buffers,
                    # but that requires a larger BAR size and thus Above 4G decoding.
                    #
                    # we also shouldn't wait for the GPU to finish processing the data,
                    # but that requires more careful design that's out of scope here.
            
                    arr = unsafe_wrap(CuArray{Complex{Int16}, 1}, reinterpret(CuPtr{Complex{Int16}}, buffs[1]), Int(mtu*num_channels))
                    if !initialized_count
                        #setup arrays for comparison
                        CUDA.@allowscalar counter = Int32(real(arr[1])) & 0xfff | ((Int32(imag(arr[1])) & 0xfff) << 12)
                        initialized_count = true
                    end

                    # copy the array over to the CPU for validation
                    copyto!(comp, arr)

                    for j in eachindex(comp)
                        @assert comp[j] == Complex{Int16}(counter & 0xfff, (counter >> 12) & 0xfff)
                        counter = (counter + 1) & 0xffffff
                    end

                    #arr .= 1        # to verify we can actually do something with this
                    synchronize()   # data without running into overflows
                else
                    # if we have an overflow conditions we can just use the MTU

                    if lfsr_mode
                        buf = unsafe_wrap(Array{UInt16}, reinterpret(Ptr{UInt16}, buffs[1]), Int(mtu*num_channels*2))
                        # LFSR data check
                        for j in 1:2:length(buf)-1
                            @assert buf[j] == ((~buf[j+1]) & 0x0fff)
                        end
                    else
                        buf = unsafe_wrap(Array{Complex{Int16}}, reinterpret(Ptr{Complex{Int16}}, buffs[1]), Int(mtu*num_channels))
                        # sync the counter on start
                        if !initialized_count
                            counter = Int32(real(buf[1])) & 0xfff | ((Int32(imag(buf[1])) & 0xfff) << 12)
                            initialized_count = true
                        end

                        for j in eachindex(buf)
                            z = Complex{Int16}(counter & 0xfff, (counter >> 12) & 0xfff)
                            if buf[j] != z
                                @warn("Error", received=buf[j], expected=z)
                            end
                            @assert buf[j] == z
                            counter = (counter + 1) & 0xffffff
                        end
                    end

                    buf_pointer = reinterpret(Ptr{UInt32}, buffs[1])

                    # make sure we aren't recycling the same buffer
                    if i != 1
                        @assert prior_pointer != buf_pointer
                    end

                    prior_pointer = buf_pointer
                end


                SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
                total_bytes += bytes
            end
            @info "Data rate: $(Base.format_bytes(total_bytes / time))/s"
            @info "Overflow Events: $overflow_events"

        end
    end
end

using CUDA
# GPU: initialize the device# GPU: initialize the device
device!(0)
CuArray(UInt32[1]) .= 1
# XXX: actually creating an array to initialize CUDA won't be required anymore
#      in the next version of CUDA.jl, but it helps to ensure code is compiled

using Base.Threads

for dev_args in Devices(driver="XTRX")
    try
        dma_test(dev_args;use_gpu=false, lfsr_mode=true)
        dma_test(dev_args;use_gpu=false, lfsr_mode=false)
        dma_test(dev_args;use_gpu=true, lfsr_mode=false)
    catch e
        @error("failed on $(dev_args["path"]), serial: $(dev_args["serial"])")
        @error(e)
    end
end
