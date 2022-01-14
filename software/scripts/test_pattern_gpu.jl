# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

using SoapySDR, CUDA

# GPU: initialize the device
device!(0)
CuArray(UInt32[1]) .= 1
# XXX: actually creating an array to initialize CUDA won't be required anymore
#      in the next version of CUDA.jl, but it helps to ensure code is compiled

# open the first device
devs = Devices()
dev_args = devs[1]
dev_args["device"] = "GPU"
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

function dma_test(stream)
    SoapySDR.activate!(stream)

    try
        # acquire buffers using the low-level API
        buffs = Ptr{UInt32}[C_NULL]
        bytes = 0
        total_bytes = 0

        println("Receiving data")
        time = @elapsed for i in 1:1000
            bytes, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream, buffs)
            arr = unsafe_wrap(CuArray, reinterpret(CuPtr{UInt32}, buffs[1]), bytes ÷ sizeof(UInt32))
            arr .= 1        # to verify we can actually do something with this
            synchronize()   # data without running into overflows

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

        # print last array, for verification
        arr = unsafe_wrap(CuArray, reinterpret(CuPtr{UInt32}, buffs[1]), bytes ÷ sizeof(UInt32))
        display(arr[1:10])
        println("\n ...")
    finally
        SoapySDR.deactivate!(stream)
    end
end
CUDA.@profile dma_test(stream)

# close everything
close(stream)
close(dev)
