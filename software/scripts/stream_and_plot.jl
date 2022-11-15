#ENV["SOAPY_SDR_LOG_LEVEL"] = "DEBUG"

using SoapySDR, Printf, Unitful, DSP, LibSigflow, SoapyBladeRF_jll, LibSigGUI
include("./xtrx_debugging.jl")

if Threads.nthreads() < 2
    error("This script must be run with multiple threads!")
end

function stream_and_plot_periodogram(;
    frequency = 1575.42u"MHz",
    sample_rate = 6u"MHz",
#    gain = 60u"dB",
)

    Device(first(Devices())) do dev

        fig, close_stream_event = open_and_display_figure()

        # Setup receive parameters
        for cr in dev.rx
            cr.bandwidth = sample_rate
            cr.frequency = frequency
            cr.sample_rate = sample_rate
            # Gain does not seem to have an effect with BladeRF
            # Even if gain_mode is set to false
#            cr.gain = gain
            cr.gain_mode = true
        end

        # Construct streams
        stream_rx = SoapySDR.Stream(ComplexF32, dev.rx)

        samples_channel = stream_data(stream_rx, close_stream_event; leadin_buffers=0)
        reshunked_channel = rechunk(samples_channel, 10000)

        periodograms = calc_periodograms(reshunked_channel, sampling_freq = upreferred(sample_rate / 1u"Hz"))
        plot_periodograms(periodograms; fig)
    end
end

function stream_and_plot(;
    frequency = 1575.42u"MHz",
    sample_rate = 6u"MHz",
#    gain = 60u"dB",
)

    Device(first(Devices())) do dev

        fig, close_stream_event = open_and_display_figure()

        # Setup transmission/recieve parameters
        for cr in dev.rx
            cr.bandwidth = sample_rate
            cr.frequency = frequency
            cr.sample_rate = sample_rate
            # Gain does not seem to have an effect with BladeRF
            # Even if gain_mode is set to false
#            cr.gain = gain
            cr.gain_mode = true
        end

        # Construct streams
        stream_rx = SoapySDR.Stream(ComplexF32, dev.rx)

        samples_channel = stream_data(stream_rx, close_stream_event; leadin_buffers=0)
        reshunked_channel = rechunk(samples_channel, 10000)
        float_signal = complex2float(real, reshunked_channel)
        plot_signal(float_signal; fig)        
    end
end