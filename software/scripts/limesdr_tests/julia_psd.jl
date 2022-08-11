# Ensure that our JLL preferences are setup properly to load our custom-built libraries
include("../julia_preferences_setup.jl")
include("../libsigflow.jl")

# Don't let GR try to open any windows
ENV["GKSwstype"]=100

using SoapySDR, SoapyLMS7_jll, Unitful, Statistics, Printf, FFTW, Plots, Plots.PlotMeasures, Profile
using DSP: hanning
using SoapySDR: dB

function stream_psd(freq::Unitful.Frequency,
                    fs::Unitful.Frequency,
                    capture_time::Unitful.Time;
                    freq_res::Unitful.Frequency = 10u"kHz",
                    time_res::Unitful.Time = 10u"ms",
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
            c_data = log_stream_xfer(c_data; print_period=10)

            # Calculate FFTs on another thread
            buff_size = round(Int, upreferred(fs * time_res))
            freq_points = round(Int, upreferred(fs / freq_res))
            return collect_psd(rechunk(c_data, buff_size), freq_points, buff_size)
        end
    end
end

function spectrum_scan(start_freq::Unitful.Frequency, end_freq::Unitful.Frequency;
                       sample_rate::Unitful.Frequency = 40u"MHz",
                       capture_time::Unitful.Time = 30u"s",
                       overlap = 0.15)
    freq_step = sample_rate*(1 - 2*overlap)
    carrier_frequencies = start_freq:freq_step:(end_freq + freq_step)
    
    psds = Matrix{Float32}[]
    for carrier_freq in carrier_frequencies
        psd = stream_psd(carrier_freq, sample_rate, capture_time)
        # Chop off `overlap` on either side of the frequency, to drop off the LPF transition band
        psd = psd[round(Int, size(psd, 1)*overlap)+1 : round(Int, size(psd, 1)*(1 - overlap)), :, 1]
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
    freq_mean = vec(mean(psd, dims=2))
    time_mean = vec(mean(psd, dims=1))

    # Bin each mean to a reasonalbe number of points
    bin(x, N) = [mean(x[(idx-1)*div(end,N)+1:idx*div(end,N)]) for idx in 1:N]
    freq_mean = bin(freq_mean, 200)
    time_mean = bin(time_mean, 200)

    # Create layout with large b, smaller a and c on the sides
    layout = @layout[
        a             _
        b{0.8w, 0.8h} c
    ]
    p = plot(;layout, link=:both, margin=0px)

    heatmap!(p,
        # Time in seconds
        LinRange(0, uconvert(u"s", capture_time).val, size(psd,2)),
        # Frequency, in hertz
        LinRange(uconvert(u"MHz", min_freq).val, uconvert(u"MHz", max_freq).val, size(psd, 1)),
        # power spectral density
        log.(psd);
        xlabel = "Time (s)",
        ylabel = "Frequency (MHz)",
        # Plot into `b` in the layout above
        subplot = 2,
        framestyle = :box,
        colorbar = nothing,
        margin = 0px,
    )
    plot!(p,
        LinRange(0, capture_time.val, length(time_mean)),
        time_mean,
        subplot = 1,
        color = "black",
        framestyle = :none,
        legend = nothing,
        margin = 0px,
        title="Power Spectral Density",
    )
    plot!(p,
        LinRange(uconvert(u"MHz", min_freq).val, uconvert(u"MHz", max_freq).val, length(freq_mean)),
        freq_mean,
        subplot = 3,
        color = "black",
        framestyle = :none,
        permute = (:x, :y),
        legend = nothing,
        margin = -100px,
    )
    filename = @sprintf("power_spectral_density_%.1fGHz-%.1fHGz_%ds.png", uconvert(u"GHz", min_freq).val, uconvert(u"GHz", max_freq).val, uconvert(u"s", capture_time).val)
    @info("Saving", filename)
    savefig(p, filename)
    return nothing
end


# Get a stacked PSD for the frequency sweep we just performed
psd, capture_time, min_freq, max_freq = spectrum_scan(2.4u"GHz", 2.5u"GHz")

# Save it out to a picture
save_psd_plot(psd, capture_time, min_freq, max_freq)
