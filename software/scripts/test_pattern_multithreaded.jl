# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

using SoapySDR, Unitful, Test, LibSigflow
import LibSigflow: un_sign_extend!

include("./xtrx_debugging.jl")

if Threads.nthreads() < 2
    error("This script must be run with multiple threads!")
end


#SoapySDR.register_log_handler()

# Disable GC for this test to minimize underflows
GC.enable(false)

function dma_test(dev_args)
    Device(dev_args) do dev
        # Try increasing `sample_rate`
        sample_rate = 1u"MHz"
        for cr in dev.rx
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

        buffs_processed = 0
        total_bytes = 0
        initialized_count = false
        counter = Int32(0)
        errors = Int64(0)

        c = stream_data(stream, mtu*wr_nbufs*2000; leadin_buffers=0)
        c = membuffer(c)

        # Log out information about data rate and such
        c = log_stream_xfer(c; extra_values=() -> (;errors, total_bytes, counter=UInt32(counter)))

        consume_channel(c) do buff
            # libsigflow permutes our data into a standardized ordering
            # let's un-permute to get back to the native ordering, which
            # is better for this test.
            pbuff = permutedims(buff)

            # We also don't really want the sign extension that the XTRX driver does, so let's undo that:
            un_sign_extend!(pbuff)

            # Pick up wherever we are in the sequence
            if !initialized_count
                counter = Int32(real(pbuff[1])) & 0xfff | ((Int32(imag(pbuff[1])) & 0xfff) << 12)
                initialized_count = true
            end

            for j in eachindex(pbuff)
                comp = Complex{Int16}(counter & 0xfff, (counter >> 12) & 0xfff)
                if pbuff[j] != comp
                    # We may fail a few times while compiling at first, because we'll drop buffers.
                    # but eventually, we should be able to keep up with the data stream, as long as
                    # it's low enough.
                    @warn("Error", j, pbuff[j], comp, buffs_processed, _num_overflows[])
                    errors += 1
                    initialized_count = false
                    break
                end
                counter = (counter + 1) & 0xffffff
            end
            total_bytes += sizeof(buff)
            buffs_processed += 1
        end
    end
end

dma_test(first(Devices(driver="XTRX")))
