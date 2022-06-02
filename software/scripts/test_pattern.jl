# configure the XTRX to generate a data pattern in the FPGA,
# and try receiving that pattern using the LMS7002M RF IC.
# the pattern is just a counter, so the array should contain increasing numbers.

if isempty(ENV["SOAPY_SDR_PLUGIN_PATH"])
    ENV["SOAPY_SDR_PLUGIN_PATH"] = joinpath(@__DIR__, "../soapysdr/build")
end

@show ENV["SOAPY_SDR_PLUGIN_PATH"]

using SoapySDR


# open the first device
devs = Devices()
dev_args = devs[1]
# GPU: set the DMA target
dev_args["device"] = "CPU"
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
        time = @elapsed for i in 1:100
            bytes, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream, buffs)
            SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream, handle)
            total_bytes += bytes
        end
        println("Data rate: $(Base.format_bytes(total_bytes / time))/s")

        # print last array, for verification
        arr = unsafe_wrap(Array, buffs[1], bytes ÷ sizeof(UInt32))
        # GPU: wrap as a CuArray instead
        # arr = unsafe_wrap(CuArray, reinterpret(CuPtr{UInt32}, buffs[1]), bytes ÷ sizeof(UInt32))
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
