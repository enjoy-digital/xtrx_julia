# LFSR polynomial is x^15 + x^14 + 1. Sequence length: 2^15 - 1. Initial seed in binary is "100000000000001".
# This is how the data are constructed for AI, AQ, BI and BQ channels:
# 1. AI: Twelve LSBs of LFSR are connected to channel AI;
# 2. AQ: Twelve inverted LSBs of LFSR are connected to channel AQ;
# 3. BI: Twelve MSBs of LFSR are connected to channel BI;
# 4. BQ: Twelve inverted MSBs of LFSR are connected to channel BQ.
# 
# Actually, there are two LFSRs - one for each A and B channels. They are enabled when RxFIFO
#  buffers are not full and RX_MUX (0x002A[11:10]) register is set to 0x2. Reset of LFSRs is
# controlled by  SRST_RXFIFO (0x0020[7]) register.

using SoapySDR
using Test

SoapySDR.register_log_handler()

function lfsr_test()

    # open the first device
    devs = Devices(parse(KWArgs, "driver=XTRX"))
    dev_args = devs[1]
    dev = Device(dev_args)

    # get the RX channel
    chan = dev.rx[1]

    # enable the TX pattern generator and loop it back
    SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE_LFSR", "TRUE")

    # open RX stream
    stream = SoapySDR.Stream(ComplexF32, [chan])

    mtu = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream)

    wr_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream)
    @info "Number of DMA buffers: $wr_nbufs"
    @info "MTU: $mtu"


    try
        # acquire buffers using the low-level API
        buffs = Ptr{UInt32}[C_NULL]
        bytes = mtu*4
        total_bytes = 0

        prior_pointer = Ptr{UInt32}(0)
        counter = one(Int16)

        #comp = Vector{Complex{Int16}}(undef, mtu)

        overflow_events = 0

        initialized_count = false

        @info "Receiving data..."
        SoapySDR.activate!(stream)
        time = @elapsed for i in 1:300
            err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream, buffs)
            if err == SoapySDR.SOAPY_SDR_OVERFLOW
                overflow_events += 1
            elseif err == SoapySDR.SOAPY_SDR_TIMEOUT
                SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
                continue
            end

            # if we have an overflow conditions we can just use the MTU
            buf = unsafe_wrap(Array{UInt16}, reinterpret(Ptr{UInt16}, buffs[1]), mtu)

            buf_pointer = reinterpret(Ptr{UInt32}, buffs[1])

            # sync the counter on start
            if !initialized_count
                #SoapySDR.SoapySDRDevice_writeSetting(dev, "RESET_RX_FIFO", "TRUE")
                #counter = Int16(real(buf[1]))
                @show buf
                initialized_count = true
            end

            # make sure we aren't recycling the same buffer
            if i != 1
                @assert prior_pointer != buf_pointer
            end



            # LFSR data check
            for i in 1:2:length(buf)-1
                @assert buf[i] != ((~buf[i+1]) & 0x0fff)
            end
            
            #errs = PhysicalCommunications.sequence_detecterrors(MaxLFSR(15), buf)
            #@show errs

            prior_pointer = buf_pointer


            SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
            total_bytes += bytes
        end
        @info "Data rate: $(Base.format_bytes(total_bytes / time))/s"
        @info "Overflow Events: $overflow_events"

    finally
        SoapySDR.deactivate!(stream)
    end
    finalize(stream)
    finalize(dev)
end

lfsr_test()

