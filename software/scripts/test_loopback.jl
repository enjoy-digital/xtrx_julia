# configure loopback mode in the the XTRX and LMS7002M RF IC, so transmitted
# buffers should appear on the RX side.

if !haskey(ENV, "SOAPY_SDR_PLUGIN_PATH") || isempty(ENV["SOAPY_SDR_PLUGIN_PATH"])
    ENV["SOAPY_SDR_PLUGIN_PATH"] = joinpath(@__DIR__, "../soapysdr/build")
end

@show ENV["SOAPY_SDR_PLUGIN_PATH"]

using SoapySDR, Printf

SoapySDR.register_log_handler()

const seed_base = rand(UInt16)
const seed_wr = Ref{UInt16}(0)
const seed_rd = Ref{UInt16}(0)
seed_to_val(seed) = seed * seed_base + 1

function write_pn_data(buf::Ptr{T}, sz, max_sz, data_width=12) where {T}
    mask = (UInt16(1) << data_width) - UInt16(1)
    nels = sz÷sizeof(T)
    for i = 1:nels
        unsafe_store!(buf, seed_to_val(seed_wr[]) & mask, i)
        seed_wr[] = (seed_wr[] + 1) % (max_sz ÷ sizeof(T)) % T
    end

    return
end

function check_pn_data(buf::Ptr{T}, sz, max_sz, data_width=12) where {T}
    mask = (UInt16(1) << data_width) - UInt16(1)
    nels = sz÷sizeof(T)
    errors = 0
    for i = 1:nels
        if unsafe_load(buf, i) != (seed_to_val(seed_rd[]) & mask)
            errors += 1
        end
        seed_rd[] = (seed_rd[] + 1) % (max_sz ÷ sizeof(T)) % T
    end

    return errors
end

function dma_test()
    # open the first device
    devs = Devices()
    dev = open(devs[1])

    # get the RX and TX channels
    chan_rx = dev.rx[1]
    chan_tx = dev.tx[1]

    # enable a loopback
    SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")
    # NOTE: we use the LMS7002M's loopback to validate the entire chain,
    #       but this also works with the FPGA's loopback

    # open RX and TX streams
    stream_rx = SoapySDR.Stream(ComplexF32, [chan_rx])
    stream_tx = SoapySDR.Stream(ComplexF32, [chan_tx])

    # the size of every buffer, in bytes
    wr_sz = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream_tx)
    rd_sz = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream_rx)
    @assert wr_sz == rd_sz

    # the number of buffers each stream has
    wr_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_tx)
    rd_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_rx)
    @assert wr_nbufs == rd_nbufs


    # the total size of the stream's buffers, in bytes
    wr_total_sz = wr_sz * wr_nbufs
    rd_total_sz = rd_sz * rd_nbufs
    @info "number of buffers: $(Int(wr_nbufs)), buffer size (bytes): $(Int(wr_sz))"

    run = false

    try
        errors = 0
        iterations = 0

        get_time_ms() = trunc(Int, time() * 1000)
        last_time = get_time_ms()
        read_bytes = 0
        written_bytes = 0
        last_written_bytes = 0

        SoapySDR.activate!(stream_tx)
        SoapySDR.activate!(stream_rx)

        while true

            # write tx-buffer
            i = 1
            while true
                buffs = Ptr{UInt16}[C_NULL]
                err, handle = SoapySDR.SoapySDRDevice_acquireWriteBuffer(dev, stream_tx, buffs, 0)
                if err == SoapySDR.SOAPY_SDR_TIMEOUT
                    break
                elseif err == SoapySDR.SOAPY_SDR_UNDERFLOW
                    err = wr_sz # nothing to do, should be the MTU
                end
                @assert err > 0
                write_pn_data(buffs[1], err, wr_total_sz)
                SoapySDR.SoapySDRDevice_releaseWriteBuffer(dev, stream_tx, handle, 1)
                written_bytes += err
                i += 1
            end

            # read/check rx-buffer
            while true
                buffs = Ptr{UInt16}[C_NULL]
                err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream_rx, buffs, 0)
                if err == SoapySDR.SOAPY_SDR_TIMEOUT
                    break
                elseif err == SoapySDR.SOAPY_SDR_OVERFLOW
                    err = rd_sz # nothing to do, should be the MTU
                end
                @assert err > 0
                if handle >= wr_nbufs
                    if run
                        errors += check_pn_data(buffs[1], err, rd_total_sz)
                    else
                        errors_min = typemax(Int)
                        error_threshold = (rd_sz ÷ sizeof(UInt16)) ÷ 2
                        for delay = 0:wr_sz
                            seed_rd[] = delay
                            errors = check_pn_data(buffs[1], err, rd_total_sz)
                            if errors < errors_min
                                errors_min = errors
                            end
                            if errors <= error_threshold
                                println("RX_DELAY: $delay (errors: $errors)")
                                run = true
                                break
                            end
                        end
                        read_bytes += err
                        run ||
                            error("Unable to find DMA RX_DELAY (min errors: $(errors_min)/$(error_threshold))")
                    end
                end
                SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream_rx, handle)
            end

            # statistics
            duration = get_time_ms() - last_time
            if duration > 200
                read_buffers = read_bytes ÷ rd_sz
                written_buffers = written_bytes ÷ wr_sz
                data_width = 12

                if iterations % 10 == 0
                    println("\e[1mDMA_SPEED(Gbps)\tTX_BUFFERS\tRX_BUFFERS\tDIFF\tERRORS\e[0m")
                end
                iterations += 1

                @printf("%14.2f\t%10i\t%10i\t%4i\t%6u\n",
                   (written_bytes - last_written_bytes) * 8 * data_width / (16 * duration * 1e6),
                   written_buffers,
                   read_buffers,
                   written_buffers - read_buffers,
                   errors)

                errors = 0
                last_time = get_time_ms()
                last_written_bytes = written_bytes
            end
        end
    finally
        SoapySDR.deactivate!(stream_rx)
        SoapySDR.deactivate!(stream_tx)
    end
    # close everything
    close.([stream_rx, stream_tx])
    close(dev)
end
dma_test()


