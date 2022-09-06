# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

using SoapySDR, Unitful, Test

include("./libsigflow.jl")
include("./xtrx_debugging.jl")

if Threads.nthreads() < 2
    error("This script must be run with multiple threads!")
end


#SoapySDR.register_log_handler()

# Disable GC for this test to minimize underflows
GC.enable(false)

function dma_test(dev_args)
    Device(dev_args) do dev
        # Setup transmission/recieve parameters
        set_cgen_freq(dev, 64u"MHz")
        sample_rate = 2u"MHz"
        for (c_idx, cr) in enumerate(dev.rx)
            cr.sample_rate = sample_rate
        end
        for ct in dev.tx
            ct.sample_rate = sample_rate
        end

        SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE_LFSR", "FALSE")
        SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "")
        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_PATTERN", "1")
        SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")

        # open MIMO RX stream
        stream = SoapySDR.Stream(dev.rx[1].native_stream_format, dev.rx)

        mtu = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream)
        wr_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream)
        @info "Number of DMA buffers: $wr_nbufs"
        @info "MTU: $mtu"

        total_bytes = 0
        initialized_count = false

        c = stream_data(stream, mtu*wr_nbufs*2000; auto_sign_extend=false, leadin_buffers=0)

        # Log out information about data rate and such
        c = log_stream_xfer(c)

        counter = 0
        consume_channel(c) do buff
            # Pick up wherever we are in the sequence
            if !initialized_count
                counter = (real(buff[1]) & 0xfff) + ((imag(buff[1]) & 0xfff) << 12)
                initialized_count = true
            end

            # libsigflow permutes our data into a standardized ordering
            # let's un-permute to get back to the native ordering, which
            # is better for this test.
            pbuff = permutedims(buff)
            for j in eachindex(pbuff)
                comp = Complex{Int16}(counter & 0xfff, (counter >> 12) & 0xfff)
                if pbuff[j] != comp
                    @error("fail", j, pbuff[j], comp, total_bytes)
                end
                @assert pbuff[j] == comp
                counter = (counter + 1) & 0xffffff
            end
            total_bytes += sizeof(buff)
        end
    end
end

dma_test(first(Devices(driver="XTRX")))
