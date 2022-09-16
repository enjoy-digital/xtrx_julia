# Ensure that our JLL preferences are setup properly to load our custom-built libraries
include("../julia_preferences_setup.jl")
include("../libsigflow.jl")

using SoapySDR, SoapyLMS7_jll, Unitful, Profile

devs = Devices()
for (idx, dev) in enumerate(devs)
    @info("Found device #$(idx)", label=dev["label"])
end

Profile.clear()
Device(devs[1]) do dev
    @info("Device:")
    display(dev)
    println()

    @info("RX channel")
    c_rx = dev.rx[1]
    display(c_rx)
    println()

    # Configure the channel, then open a stream of complex float32's
    c_rx.sample_rate = 40u"MHz"
    c_rx.frequency = 912.36u"MHz"
    SoapySDR.Stream(ComplexF32, [c_rx]) do s_rx
        SoapySDR.activate!(s_rx) do
            ten_seconds_of_samples = round(Int, upreferred(c_rx.sample_rate).val*10)
            c_data = stream_data(s_rx, ten_seconds_of_samples)
            @profile consume_channel(log_stream_xfer(c_data)) do buff
            end
        end
    end
end
