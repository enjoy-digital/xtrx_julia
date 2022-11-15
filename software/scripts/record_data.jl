ENV["GKSwstype"] = "100"
#ENV["SOAPY_SDR_LOG_LEVEL"] = "DEBUG"

using SoapySDR, Printf, Unitful, DSP, LibSigflow, SoapyBladeRF_jll
include("./xtrx_debugging.jl")

if Threads.nthreads() < 2
    error("This script must be run with multiple threads!")
end

function record_data(;
    data_length::typeof(1u"ms") = 10_000u"ms",
    frequency = 1575.42u"MHz",
    sample_rate = 6u"MHz",
    files_path = "/home/schoenbrod/Messungen/bladerf/antenna",
    gain = 60u"dB"
)

    Device(first(Devices())) do dev

        # Setup receive parameters
        for cr in dev.rx
            cr.bandwidth = sample_rate
            cr.frequency = frequency
            cr.sample_rate = sample_rate

            cr.gain_mode = true
        end
        num_samples = Int(upreferred(data_length * sample_rate))

        # Construct streams
        stream_rx = SoapySDR.Stream(ComplexF32, dev.rx)

        samples = stream_data(stream_rx, num_samples; leadin_buffers=0)
        write_to_file(samples, files_path)
        
    end
end