# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

using SoapySDR

# GPU: initialize the device
#using CUDA
#CuArray([1])

# open the first device
devs = Devices()
dev_args = devs[1]
# GPU: set the DMA target
#dev_args["device"] = "GPU"
dev = open(dev_args)

# get the RX channel
chan = dev.rx[1]

# enable pattern generator
SoapySDR.SoapySDRDevice_writeSetting(dev, "TX_PATTERN", "1")

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
        time = @elapsed for i in 1:100
            bytes, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream, buffs)
            SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
            total_bytes += bytes
        end
        println("Data rate: $(Base.format_bytes(total_bytes / time))/s")

        # print last array, for verification
        arr = unsafe_wrap(Array, buffs[1], bytes ÷ sizeof(UInt32))
        # GPU: wrap as a CuArray instead
        #unsafe_wrap(CuArray, reinterpret(CuPtr{UInt32}, buffs[1]), ...)
        display(arr[1:10])
        println("\n ...")
    finally
        SoapySDR.deactivate!(stream)
    end
end
dma_test(stream)

# close everything
close(stream)
close(dev)
