# Ensure that our JLL preferences are setup properly to load our custom-built libraries
include("../julia_preferences_setup.jl")
include("../libsigflow.jl")

# Don't let GR try to open any windows
ENV["GKSwstype"]=100

using SoapySDR, SoapyLMS7_jll, Unitful, Statistics, Printf, FFTW, Plots
using DSP: hanning

function collect_psd(c, F, buff_size; verbose::Bool = false)
    # Vector to store FFT output, FFTW pre-plan, and time window
    BUFF = Vector{ComplexF32}(undef, F)
    fft_plan = FFTW.plan_fft(BUFF)
    win = Float32.(hanning(F))

    # We'll store our PSD frames here, then concatenate into a giant matrix later
    psd_frames = Vector{Float32}[]
    time_accumulation = div(buff_size, F)
    if verbose
        @info("Collecting freq stats", F, buff_size, time_accumulation)
    end
    consume_channel(rechunk(c, buff_size)) do data
        psd_frame = zeros(Float32, F)

        for idx in 1:time_accumulation
            FFTW.mul!(BUFF, fft_plan, data[(idx-1)*F+1:idx*F] .* win)
            # We use `max()` here instead of accumulating into the `psd_frame`
            # so that activity stands out more aggressively, although it does increase noise.
            psd_frame = max.(psd_frame, FFTW.fftshift(abs.(BUFF)))
        end
        #push!(psd_frames, psd_frame./time_accumulation)
        push!(psd_frames, psd_frame)
    end
    return hcat(psd_frames...)
end

function stream_psd(freq::Unitful.Frequency,
                    fs::Unitful.Frequency,
                    capture_time::Unitful.Time;
                    freq_res::Unitful.Frequency = 10u"kHz",
                    time_res::Unitful.Time = 10u"ms",
                    verbose::Bool = false,
                    )
    # Standardize our units
    fs = uconvert(u"Hz", fs)
    freq = uconvert(u"Hz", freq)
    capture_time = uconvert(u"s", capture_time)

    freq_res = uconvert(u"Hz", freq_res)
    time_res = uconvert(u"s", time_res)
    Device(first(Devices(parse(KWArgs, "driver=lime")))) do dev
        # Configure the channel, then open a stream of complex float32's
        c_rx = dev.rx[1]
        c_rx.sample_rate = fs
        c_rx.bandwidth = fs
        c_rx.frequency = freq

        # Default to 40dB, and turn off AGC
        c_rx.gain = 40dB
        c_rx.gain_mode = false

        SoapySDR.Stream(ComplexF32, [c_rx]) do s_rx
            # Get a stream of data for as many samples as requested
            num_samples = round(Int, upreferred(fs * capture_time))
            c_data = stream_data(s_rx, num_samples)

            # Log some information out to the console
            if verbose
                c_data = log_stream_xfer(c_data)
            end

            # Calculate FFTs on another thread
            buff_size = round(Int, upreferred(fs * time_res))
            freq_points = round(Int, upreferred(fs / freq_res))
            t_freq = Threads.@spawn collect_psd(c_data, freq_points, buff_size; verbose)

            return fetch(t_freq)
        end
    end
end

function spectrum_scan(start_freq::Unitful.Frequency, end_freq::Unitful.Frequency;
                       sample_rate::Unitful.Frequency = 30u"MHz",
                       capture_time::Unitful.Time = 30u"s",
                       overlap = 0.15)
    freq_step = sample_rate*(1 - 2*overlap)
    carrier_frequencies = start_freq:freq_step:(end_freq + freq_step)
    
    psds = Matrix{Float32}[]
    for carrier_freq in carrier_frequencies
        psd = stream_psd(carrier_freq, sample_rate, capture_time; verbose=true)
        # Chop off `overlap` on either side of the frequency, to drop off the LPF transition band
        psd = psd[round(Int, size(psd, 1)*overlap)+1 : round(Int, size(psd, 1)*(1 - overlap)), :]
        push!(psds, psd)
    end

    # Stack the different psd's on top of eachother
    psd = vcat(psds...)
    min_freq = minimum(carrier_frequencies) - (sample_rate/2)*(1 - overlap)
    max_freq = maximum(carrier_frequencies) + (sample_rate/2)*(1 - overlap)
    return psd, capture_time, min_freq, max_freq    
end

function save_psd_plot(psd, capture_time, min_freq, max_freq)
    @info("Saving frequency-domain plot...", num_time_points=size(psd,2), num_freq_points=size(psd,1))
    p = heatmap(
        # Time in seconds
        LinRange(0, capture_time.val, size(psd,2)),
        # Frequency, in hertz
        LinRange(uconvert(u"MHz", min_freq).val, uconvert(u"MHz", max_freq).val, size(psd, 1)),
        # power spectral density
        log.(psd);
        xlabel = "Time (s)",
        ylabel = "Frequency (MHz)",
    )
    filename = @sprintf("power_spectral_density_%.1fGHz-%.1fHGz_%ds.png", uconvert(u"GHz", min_freq).val, uconvert(u"GHz", max_freq).val, uconvert(u"s", capture_time).val)
    savefig(p, filename)
    return nothing
end


# Get a stacked PSD for the frequency sweep we just performed
psd, capture_time, min_freq, max_freq = spectrum_scan(2.4u"GHz", 2.5u"GHz")

# Save it out to a picture
save_psd_plot(psd, capture_time, min_freq, max_freq)
