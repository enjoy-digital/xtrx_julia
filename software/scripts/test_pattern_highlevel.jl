# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

using SoapySDR
using Test
using Unitful

#SoapySDR.register_log_handler()

function dma_test(dev_args;lfsr_mode=false, show_mismatch=false)

    Device(dev_args) do dev
        # get the RX channel
        chans = dev.rx

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

        # open RX stream
        stream = SoapySDR.Stream(chans)

        mtu = stream.mtu
        num_channels = Int(length(dev.rx))

        # we want to go through the ring buffer a few times.        
        rd_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream)
        nbufs = rd_nbufs*3

        # pre allocate memory to copy the data into.
        bufs = ntuple(_->Vector{chans[1].native_stream_format}(undef, mtu*nbufs), num_channels)

        total_bytes = nbufs*mtu*sizeof(chans[1].native_stream_format)*num_channels

        @info "MTU: $mtu, Buffer Count: $(rd_nbufs)"

        @info "Receiving data..."
        time_rd = @elapsed SoapySDR.activate!(stream) do
            read!(stream, bufs; timeout=1u"s")
        end

        @info "Data read rate: $(Base.format_bytes(total_bytes / time_rd))/s, Total Bytes: $(Base.format_bytes(total_bytes))"

        error_count = 0

        time_validation = @elapsed begin

            counter = Int32(real(bufs[1][1])) & 0xfff | ((Int32(imag(bufs[1][1])) & 0xfff) << 12)

            for j in 1:length(bufs[1])
                # the counter is 24 bits.
                z1 = Complex{Int16}(counter & 0xfff, (counter >> 12) & 0xfff)
                z2 = Complex{Int16}((counter + 1) & 0xfff, ((counter + 1) >> 12) & 0xfff)
                if bufs[1][j] != z1 || bufs[2][j] != z2
                    show_mismatch && @warn("Error", received=(bufs[1][j], bufs[2][j]), expected=(z1, z2), at=j)
                    error_count = error_count + 1
                end
                counter = counter + 0x2
            end
        end

        @info "Data validation rate: $(Base.format_bytes(total_bytes / time_validation))/s, Total Bytes: $(Base.format_bytes(total_bytes))"

        if error_count > 0
            @warn "Total error count: $error_count/$(length(bufs[1]))"
        end
    end
end

function main()
    for dev_args in Devices(driver="XTRX")
        GC.enable(false)
        try
            #dma_test(dev_args; lfsr_mode=true)
            dma_test(dev_args; lfsr_mode=false)
        catch e
            @error "Test failed" path=dev_args["path"] serial=dev_args["serial"] exception=(e, catch_backtrace())
        end
        GC.gc()
    end
end

isinteractive() || main()
