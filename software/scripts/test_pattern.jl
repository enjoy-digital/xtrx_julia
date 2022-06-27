# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

if !haskey(ENV, "SOAPY_SDR_PLUGIN_PATH") || isempty(ENV["SOAPY_SDR_PLUGIN_PATH"])
    ENV["SOAPY_SDR_PLUGIN_PATH"] = joinpath(@__DIR__, "../soapysdr/build")
end

@show ENV["SOAPY_SDR_PLUGIN_PATH"]

using SoapySDR
using Test

SoapySDR.register_log_handler()

const GPU = Ref(false)

if "gpu" in ARGS
    using CUDA
    GPU[] = true

    # GPU: initialize the device# GPU: initialize the device
    device!(0)
    CuArray(UInt32[1]) .= 1
    # XXX: actually creating an array to initialize CUDA won't be required anymore
    #      in the next version of CUDA.jl, but it helps to ensure code is compiled

end


# open the first device
devs = Devices()
dev_args = devs[1]
# GPU: set the DMA target
dev_args["device"] = GPU[] ? "GPU" : "CPU"
dev = open(dev_args)

# get the RX channel
chan = dev.rx[1]

# enable the TX pattern generator and loop it back
SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_PATTERN", "1")
SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")
# NOTE: we use the LMS7002M's loopback to validate the entire chain,
#       but this also works with the FPGA's loopback

# open RX stream
stream = SoapySDR.Stream(ComplexF32, [chan])

function dma_test(stream, use_gpu=false)

    mtu = SoapySDR.SoapySDRDevice_getStreamMTU(dev, stream)


    wr_nbufs = SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream)
    @info "Number of DMA buffers:", wr_nbufs
    @info "MTU:", mtu

    buf_store = [Vector{Complex{Int16}}(undef, mtu) for _ in 1:200]

    if use_gpu
        println("Using GPU")
    else
        println("Using CPU")
    end

    try
        # acquire buffers using the low-level API
        buffs = Ptr{UInt32}[C_NULL]
        bytes = mtu ÷ 4
        total_bytes = 0

        prior_pointer = Ptr{UInt32}(0)
        counter = one(Int)

        overflow_events = 0

        println("Receiving data...")
        SoapySDR.activate!(stream)
        time = @elapsed for i in 1:200
            err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream, buffs)

            if err == SoapySDR.SOAPY_SDR_OVERFLOW
                overflow_events += 1
            end

            # if we have an overflow conditions we can just use the MTU
            buf = unsafe_wrap(Array{Complex{Int16}}, reinterpret(Ptr{Complex{Int16}}, buffs[1]), mtu ÷ 4)

            buf_pointer = reinterpret(Ptr{UInt32}, buffs[1])

            # sync the counter on start
            if i == 1
                counter = Int(real(buf[1]))
            end

            # make sure we aren't recycling the same buffer
            if i != 1
                @assert prior_pointer != buf_pointer
            end

            for j in eachindex(buf)
                @assert buf[j] == Complex{Int16}(counter, counter)
                counter = (counter + 0x1) & 0xfff
            end

            prior_pointer = buf_pointer

            # TODO
            if use_gpu
                arr = unsafe_wrap(CuArray, reinterpret(CuPtr{UInt32}, buffs[1]), bytes ÷ sizeof(UInt32))
                arr .= 1        # to verify we can actually do something with this
                synchronize()   # data without running into overflows
            end

            # GPU NOTE:
            # this is very tight with our 8K buffers: a kernel launch +
            # 8K broadcast + sync takes ~10, while at a data rate of 1Gbps we
            # can only spend ~60us per buffer. we'll need to use larger buffers,
            # but that requires a larger BAR size and thus Above 4G decoding.
            #
            # we also shouldn't wait for the GPU to finish processing the data,
            # but that requires more careful design that's out of scope here.
         
            SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
            total_bytes += bytes
        end
        println("Data rate: $(Base.format_bytes(total_bytes / time))/s")
        println("Overflow Events: ", overflow_events)
        # print last array, for verification
        arr = if use_gpu
            unsafe_wrap(CuArray, reinterpret(CuPtr{UInt32}, buffs[1]), bytes ÷ sizeof(UInt32))
        else
            unsafe_wrap(Array, buffs[1], bytes ÷ sizeof(UInt32))
        end
        display(arr[1:10])
        println("\n ...")
    finally
        SoapySDR.deactivate!(stream)
    end
end
dma_test(stream, GPU[])

# close everything
close(stream)
close(dev)
