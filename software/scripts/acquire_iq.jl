# configure loopback mode in the the XTRX and LMS7002M RF IC, so transmitted
# buffers should appear on the RX side.

using SoapySDR, Printf, Unitful, DSP
include("./libsigflow.jl")

# Don't let GR segfault
ENV["GKSwstype"]="100"

SoapySDR.register_log_handler()


function do_txrx(;digital_loopback::Bool = false, lfsr_loopback::Bool = false, dump_inis::Bool = false)
    # open the first device
    Device(first(Devices())) do dev
        # Get some useful parameters
        format = dev.rx[1].native_stream_format
        fullscale = dev.tx[1].fullscale

        # Setup transmission/recieve parameters
        for cr in dev.rx
            cr.bandwidth = 2u"MHz"
            cr.frequency = 2.498u"GHz"
            cr.sample_rate = 2u"MHz"
            cr.antenna = :LNAW
            cr[SoapySDR.GainElement(:PGA)] = 6u"dB"
        end

        for ct in dev.tx
            ct.bandwidth = 2u"MHz"
            ct.frequency = 2.498u"GHz"
            ct.antenna = :BAND1
            ct.sample_rate = 2u"MHz"
        end

        SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "TRUE")
        if digital_loopback
            SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")
        end
        if lfsr_loopback
            SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE_LFSR", "TRUE")
        end

        # Dump an initial INI, showing how the registers are configured here
        if dump_inis
            SoapySDR.SoapySDRDevice_writeSetting(dev, "DUMP_INI", "acquire_iq_mid_configured.ini")
        end

        # Construct streams
        stream_rx = SoapySDR.Stream(format, dev.rx)
        stream_tx = SoapySDR.Stream(format, dev.tx)

        # the number of buffers each stream has
        wr_nbufs = Int(SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_tx))
        rd_nbufs = Int(SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_rx))

        # Read 4x as many buffers as we write
        if !lfsr_loopback
            rd_nbufs *= 4
        else
            # If we're dealing with the LFSR loopback, don't get too many buffers
            # as it takes a long time to plot randomness, and don't bother to write anything
            wr_nbufs = 0
            rd_nbufs = 4
        end

        # prepare some data to send:
        rate = 10
        num_channels = Int(length(dev.tx))
        mtu = Int(stream_tx.mtu)
        samples = mtu*wr_nbufs
        t = (1:samples)./samples
        data_tx = zeros(format, num_channels, samples)

        # Create some pretty patterns to plot
        data_tx[1, :] .= format.(round.(sin.(2π.*t.*rate).*(fullscale/4).*DSP.hanning(samples)), div(fullscale,2)-1)

        # We're going to push values onto this list,
        # then concatenate them into a giant matrix at the end
        iq_data = Matrix{format}[]

        SoapySDR.activate!(stream_tx) do; SoapySDR.activate!(stream_rx) do;
            written_buffs = 0
            read_buffs = 0

            # write tx-buffer
            while written_buffs < wr_nbufs
                buffs = Ptr{format}[C_NULL]
                err, handle = SoapySDR.SoapySDRDevice_acquireWriteBuffer(dev, stream_tx, buffs, 0)
                if err == SoapySDR.SOAPY_SDR_TIMEOUT
                    break
                elseif err == SoapySDR.SOAPY_SDR_UNDERFLOW
                    err = 1 # keep going
                end
                @assert err > 0
                unsafe_copyto!(buffs[1], pointer(data_tx, num_channels*mtu*written_buffs+1), num_channels*mtu)
                SoapySDR.SoapySDRDevice_releaseWriteBuffer(dev, stream_tx, handle, 1)
                written_buffs += 1
            end

            # Take the opportunity to dump our .ini
            if dump_inis
                SoapySDR.SoapySDRDevice_writeSetting(dev, "DUMP_INI", "acquire_iq_mid_transmission.ini")
            end

            # read/check rx-buffer
            while read_buffs < rd_nbufs
                buffs = Ptr{format}[C_NULL]
                err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream_rx, buffs, 0)

                if err == SoapySDR.SOAPY_SDR_TIMEOUT
                    continue
                elseif err == SoapySDR.SOAPY_SDR_OVERFLOW
                    err = mtu # nothing to do, should be the MTU
                end
                @assert err > 0

                arr = unsafe_wrap(Matrix{format}, buffs[1], (num_channels, mtu))
                push!(iq_data, copy(arr))

                SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream_rx, handle)
                read_buffs += 1
            end
            @show read_buffs, written_buffs
        end; end

        # Concatenate into a giant matrix, then sign-extend since it's
        # most like 12-bit signed data hiding in a 16-bit buffer:
        iq_data = cat(iq_data...; dims=2)
        sign_extend!(iq_data)

        return iq_data, data_tx
    end
end

# Plot out received signals
using Plots
function make_txrx_plots(iq_data, data_tx)
    plt = plot(real.(data_tx[1, :]); label="re(data_tx)")
    plot!(plt, real.(iq_data)[1, :]; label="re(rx[1])")
    plot!(plt, real.(iq_data)[2, :]; label="re(rx[2])")
    savefig(plt, "data_re.png")

    plt = plot(imag.(data_tx[1, :]); label="im(data_tx)")
    plot!(plt, imag.(iq_data)[1, :]; label="im(rx[1])")
    plot!(plt, imag.(iq_data)[2, :]; label="im(rx[2])")
    savefig(plt, "data_im.png")
end

# Read in options from ARGS
digital_loopback = "--digital-loopback" in ARGS
lfsr_loopback = "--lfsr-loopback" in ARGS
dump_inis = "--dump-inis" in ARGS

iq_data, data_tx = do_txrx(; digital_loopback, lfsr_loopback, dump_inis)
make_txrx_plots(iq_data, data_tx)
