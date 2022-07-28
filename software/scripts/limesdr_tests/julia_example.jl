# Ensure that our JLL preferences are setup properly to load our custom-built libraries
include("../julia_preferences_setup.jl")

using SoapySDR, SoapyLMS7_jll, Unitful, Statistics

devs = Devices()
for (idx, dev) in enumerate(devs)
    @info("Found device #$(idx)", label=dev["label"])
end
dev = Device(devs[1])

@info("Device:")
display(dev)
println()

@info("RX channel")
c_rx = dev.rx[1]
display(c_rx)
println()

# Configure the channel, then open a stream of complex float32's
c_rx.sample_rate = 1u"MHz"
c_rx.frequency = 912.36u"MHz"
s_rx = SoapySDR.Stream(ComplexF32, [c_rx])

#big_buff = Vector{ComplexF32}(undef, 1024*10)
SoapySDR.activate!(s_rx; numElems=1024)
buff = Vector{ComplexF32}(undef, 1024)
for idx in 1:10
    r = read!(s_rx, (buff,); timeout=1u"s")
    @info("read!", mean(buff))
end
SoapySDR.deactivate!(s_rx)
