# configure loopback mode in the the XTRX and LMS7002M RF IC, so transmitted
# buffers should appear on the RX side.

if !haskey(ENV, "SOAPY_SDR_PLUGIN_PATH") || isempty(ENV["SOAPY_SDR_PLUGIN_PATH"])
    ENV["SOAPY_SDR_PLUGIN_PATH"] = joinpath(@__DIR__, "../soapysdr/build")
end

@show ENV["SOAPY_SDR_PLUGIN_PATH"]

using SoapySDR, Printf, Unitful

SoapySDR.register_log_handler()


function dma_test()
    # open the first device
    devs = Devices()
    dev = Device(devs[1])

    # get the RX and TX channels
    # XX We suspect they are interlaced somehow, so analyize
    chan_rx = dev.rx[1]
    chan_tx = dev.tx[1]

    # open RX and TX streams
    format = chan_rx.native_stream_format
    fullscale = chan_tx.fullscale
    stream_rx = SoapySDR.Stream(format, dev.rx)
    stream_tx = SoapySDR.Stream(format, dev.tx)

    @info "Streaming format: $format"

    # the size of every buffer, in bytes
    mtu = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream_tx)
    wr_sz = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream_tx) * sizeof(format)
    rd_sz = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream_rx) * sizeof(format)
    @assert wr_sz == rd_sz

    # the number of buffers each stream has
    wr_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_tx)
    rd_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_rx)
    @assert wr_nbufs == rd_nbufs


    # the total size of the stream's buffers, in bytes
    wr_total_sz = wr_sz * wr_nbufs
    rd_total_sz = rd_sz * rd_nbufs
    @info "number of buffers: $(Int(wr_nbufs)), buffer size (bytes): $(Int(wr_sz))"

    # TODO Set Antennas??? GainElements??

    # Setup transmission/recieve parameters
    # XXX: Sometimes this needs to be done twice to not error???
    for cr in dev.rx
        cr.bandwidth = 500u"kHz" # 200u"kHz"
        cr.frequency = 2.498u"GHz"
        #cr.gain = 2u"dB"
        cr.sample_rate = 1u"MHz"
        @show cr.bandwidth
        @show cr.frequency
        @show cr.sample_rate
        @show cr.gain
    end

    for ct in dev.tx
        ct.bandwidth = 3.1u"MHz" #2u"MHz"
        ct.frequency = 2.498u"GHz"
        #ct.gain = 20u"dB"
        ct.sample_rate = 1u"MHz"
        @show ct.bandwidth
        @show ct.frequency
        @show ct.sample_rate
        @show ct.gain
    end

    # prepare some data to send:
    rate = 10
    samples = mtu*wr_nbufs
    t = (1:round(Int, samples))./samples
    @show length(t)
    data_tx = format.(round.(sin.(2π.*t.*rate).*fullscale/4), 0)
    data_tx_zeros = zeros(format, length(data_tx))

    iq_data = format[]

    run = false
    try

        written_buffs = 0
        read_buffs = 0

        SoapySDR.activate!(stream_tx)
        SoapySDR.activate!(stream_rx)

        @info "writing TX"
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
            unsafe_copyto!(buffs[1], pointer(data_tx, mtu*written_buffs+1), mtu)
            SoapySDR.SoapySDRDevice_releaseWriteBuffer(dev, stream_tx, handle, 1)
            written_buffs += 1
        end

        @info "reading RX"
        # read/check rx-buffer
        while read_buffs < rd_nbufs
            buffs = Ptr{format}[C_NULL]
            err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream_rx, buffs, 0)
            if err == SoapySDR.SOAPY_SDR_TIMEOUT
                continue
            elseif err == SoapySDR.SOAPY_SDR_OVERFLOW
                err = 1 # nothing to do, should be the MTU
            end
            @assert err > 0

            arr = unsafe_wrap(Vector{format}, buffs[1], mtu)
            append!(iq_data, copy(arr))

            SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream_rx, handle)
            read_buffs += 1
        end
        @show read_buffs, written_buffs

    finally
        SoapySDR.deactivate!(stream_rx)
        SoapySDR.deactivate!(stream_tx)
    end
    # close everything
    finalize.([stream_rx, stream_tx])
    finalize(dev)

    return iq_data, data_tx
end

iq_data, data_tx = dma_test()

using Plots

plt = plot(real.(iq_data)[2:2:end])
plot!(real.(iq_data)[1:2:end])
plot!(real.(data_tx))

savefig("data_$(Int(round(time()))).png")