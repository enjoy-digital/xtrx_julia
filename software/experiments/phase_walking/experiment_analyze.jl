# Don't let GR segfault
ENV["GKSwstype"] = "100"

using Plots, DSP, FFTW, Unitful
using LibSigflow
using Statistics

# Plot out received signals
function make_time_plots(iq_data, names, sample_rate; title="experiment")
    @info("Plotting $(size(iq_data,2)) channels...")
    for (f, fname) in [(real, "real"), (imag, "imaginary"), (abs, "abs"), (angle, "angle")]
        t = (0:(size(iq_data, 1)-1))/upreferred(sample_rate).val
        plt = plot(; title="$(title) - $(fname)", xlabel="Time (s)", ylabel="Amplitude")
        for i in 1:size(iq_data, 2)
            plot!(plt, t, f.(iq_data[:, i]); label="$(fname)($(names[i]))")
        end
        savefig(plt, "$(title)_$(fname).png")
        savefig(plt, "$(title)_$(fname).pdf")
    end
end

function make_fft_plots(iq_data, names, fs; title="experiment", max_freq = 50.0)
    @info("Plotting $(size(iq_data,2)) spectra...")
    DATA = abs.(fft(iq_data, 1))
    DATA_max, _ = findmax(DATA)
    DATA ./= DATA_max

    fs = uconvert(u"kHz", fs).val
    f = LinRange(0, fs, size(DATA, 1))
    plt = plot(f, DATA[:, 1]; label="|$(names[1])|", title="$(title) - Spectrum", xlabel="Frequency (kHz)", ylabel="Magnitude (normalized)")
    for i in 2:size(DATA, 2)
        plot!(plt, f, DATA[:, i]; label="|$(names[i])|")
    end
    xlims!(plt, 0, max_freq)
    savefig(plt, "$(title)_spectrum.png")
end

function relative_demod(in::Channel{Matrix{T}}) where {T}
    return spawn_channel_thread(;T=Complex{Float64}) do out
        consume_channel(in) do buff
            # Take the first channel as the reference:
            ref = buff[:, 1]
            # Divide all others by the reference, store that as output:
            out_buff = Matrix{Complex{Float64}}(undef, size(buff,1), size(buff,2)-1)
            for ch_idx in 2:size(buff,2)
                out_buff[:, ch_idx-1] = buff[:, ch_idx] ./ ref
            end
            put!(out, out_buff)
        end
    end
end

"""

    dtft(x, ω)

Calculate the DTFT of vector `x` at precisely the given angular precession rate.
"""
function dtft(x::AbstractVector{T}, ω::F) where {T, F}
    # We'll accumulate into here, typically this will be of type `ComplexF64`
    acc = zero(promote_type(T, F))
    N = length(x)

    # Perform the DTFT dot product with extra `@simd` and `@inbounds` for speed
    @inbounds @simd for idx in 1:N
        acc += x[idx]*cis(-ω*(idx-1))
    end
	return acc/N
end

"""
    dtft(x, freq, sample_rate = 1u"Hz")

Calculate the DTFT of vector `x` precisely at frequency `f` (in Hz) assuming sampling
frequency `sample_rate` (also in Hz).
"""
function dtft(x::AbstractVector{T}, freq::Unitful.Frequency, sample_rate::Unitful.Frequency = 1u"Hz") where {T}
    # Calculate the angular precession rate from our two frequencies:
    ω = 2π*upreferred(freq).val/upreferred(sample_rate).val
    return dtft(x, ω)
end

"""
    cis_snr(x::Vector{T}, X_ω, ω)

Calculate the signal to noise ratio of a sinusoid within signal `x`, given that sinusoid's DTFT
coefficient `X_ω` and its frequency `ω`.  Returns the SNR as a `dB` unit.
"""
function cis_snr(x::AbstractVector{T}, X_ω, ω::F) where {T, F}
    # Synthesize complex sinusoid, subtract that from the signal, see what's left:
    N = length(x)
    x_ω = Vector{promote_type(T,F)}(undef, N)
    @inbounds @simd for idx in 1:N
        x_ω[idx] = abs(X_ω).*cis(ω*(idx-1) .+ angle(X_ω))
    end

    # Calculate noise power
    e = x .- x_ω
    noise_power = sum(abs2, e)./N
    signal_power = abs2(X_ω)

    return 20*log10(signal_power/noise_power) * 1u"dB"
end
function cis_snr(x::AbstractVector{T}, X_ω, freq::Unitful.Frequency, sample_rate::Unitful.Frequency) where {T}
    ω = 2π*upreferred(freq).val/upreferred(sample_rate).val
    return cis_snr(x, X_ω, ω)
end

"""
    fit_sinusoid_qf(x, f0, sample_rate; maxiter = 10, tol = 1e-6)

Returns the Quinn-Fernandes estimate of the frequency (in Hz) of the largest
sinusoid in the noisy vector of samples `wf`. The sampling frequency is `fs`.

          `f` : User-provided estimate of the frequency, in radians per sample.
`sample_rate` : The sampling rate of the signal.
`maxiter`     : The Quinn-Fernandes algorithm is iterative. This argument limits the
                number of iterations. Typically the algorithm converges in 2 or 3i
                iterations.
        `tol` : Criterion for stopping the iteration. Smaller values result in more
                iterations.
"""
function fit_sinusoid_qf(x::AbstractVector{T}, f0::Unitful.Frequency, sample_rate::Unitful.Frequency; max_iter::Int=10, tol::Float64=1e-6) where T <: Complex
    # Remove any DC term in x
    x = x .- complex(mean(real.(x)), mean(imag.(x)))

    # Normalize units
    fₙ = Float64(upreferred(sample_rate).val)/2
    N = length(x)
    ω̂ = π*Float64(upreferred(f0).val)/fₙ

    # iteration
    ξ = zeros(promote_type(T,Float64), N)
    curr_iter = 0
    while curr_iter < max_iter
        # step 2
        ξ[1] = x[1]
        for t in 2:N
            ξ[t] = x[t] + exp(complex(0,ω̂))*ξ[t-1]
        end
        # step 3
        z = zero(promote_type(T,Float64))
        for t=2:N
            z += x[t]*conj(ξ[t-1])
        end
        num = imag(z*exp(complex(0,-ω̂)))
        den = sum(abs2.(ξ[1:end-1]))
        ω̂ += 2*num/den

        # stop condition
        (abs(2*num/den) < tol) && break
        curr_iter += 1
    end
    #if curr_iter >= max_iter
    #    @warn("Quinn-Fernandes max iteration reached; check your signal!", curr_iter, max_iter, f0, sample_rate, x_f0 = fₙ*ω̂/π * u"Hz")
    #end
    return fₙ*ω̂/π * u"Hz"
end

struct FreqPhaseEstimate
    # Frequency offset, in Hertz
    frequency::Float64

    # DTFT magnitude, unitless
    magnitude::Float64
    # Phase offset, in radians
    phase::Float64

    # Signal-to-noise ratio, in dB
    snr::Float64

    # The number of samples this estimate was calculated over
    num_samples::Int64

    # The data we actually calculated upon
    signal::Vector
end

function make_FP_plots(fpe_data::Matrix{FreqPhaseEstimate}, names, sample_rate; title="FPE")
    @info("Plotting $(size(fpe_data,2)) Frequency and Phase estimates...")

    for prop in [:frequency, :magnitude, :phase, :snr]
        p = plot(; title="$(title) - $(prop)", xlabel="Time (s)")
        for ch_idx in 1:size(fpe_data,2)
            ds = [getproperty(x, prop) for x in fpe_data[:, ch_idx]]
            plot!(p, ds; label="$(names[ch_idx])")
        end
        savefig(p, "$(title)_$(prop).png")
    end
end

"""
    sinusoidal_tracking(in::Channel, sample_rate, f0_estimate)

Given a sample rate and a frequency estimate, determine the dominant sinusoidal frequency and phase
that constitutes the given signal in the buffer given.  For each buffer, emit a single `FreqPhaseEstimate`
object.  Use `rechunk()` as the node before this one in the flowgraph to control time resolution.
"""
function sinusoidal_tracking(in::Channel{Matrix{T}}, sample_rate::Unitful.Frequency, f0_estimate::Unitful.Frequency) where {T}
    spawn_channel_thread(;T=FreqPhaseEstimate) do out
        consume_channel(in) do buff
            estimates = Matrix{FreqPhaseEstimate}(undef, 1, size(buff, 2))
            # For each channel, estimate its frequency and phase
            for ch_idx in 1:size(buff, 2)
                # Fit a sinusoid to this channel's data
                x = view(buff, :, ch_idx)
                x_f0 = fit_sinusoid_qf(x, f0_estimate, sample_rate)

                # Do a full DTFT to get amplitude and phase
                X_ω = dtft(x, x_f0, sample_rate)

                # Calculate SNR, for our own graphing purposes
                snr = cis_snr(x, X_ω, x_f0, sample_rate)

                estimates[1, ch_idx] = FreqPhaseEstimate(
                    upreferred(x_f0).val,
                    abs(X_ω),
                    angle(X_ω),
                    snr.val,
                    size(buff,1),
                    copy(x),
                )
            end
            put!(out, estimates)
        end
    end
end


function main()
    # Load up the latest capture
    last_capture_dir = joinpath(
        @__DIR__, "captures",
        last(readdir(joinpath(@__DIR__, "captures"))),
    )
    capture_files = filter(sort(readdir(last_capture_dir; join=true))) do f
        return endswith(f, ".sc16") && occursin("-rx", f)
    end
    names = replace.(basename.(capture_files), ".sc16" => "")
    sample_rate = 1u"MHz"
    samples_1ms = round(Int, upreferred(sample_rate).val/1000)

    c = stream_data(capture_files, Complex{Int16})

    # Divide all channels by the first channel, to get relative drifting:
    c, c_demod = tee(c)
    c_demod = relative_demod(c_demod)

    # Filter demodulation to drop higher frequency products
    filter_len = 256
    filter_coeffs = digitalfilter(Lowpass(1e3; fs=upreferred(sample_rate).val), FIRWindow(hanning(filter_len)))
    c_demod = streaming_filter(c_demod, filter_coeffs)
    
    # track frequency and phase on the raw signal
    c, c_fp = tee(c)
    c_fp = rechunk(c_fp, samples_1ms)
    c_fp = sinusoidal_tracking(c_fp, sample_rate, 20u"kHz")
    fp = @async collect_buffers(c_fp)

    # Track frequency and phase on the demodulated signal
    c_demod, c_demod_fp = tee(c_demod)
    c_demod_fp = rechunk(c_demod_fp, samples_1ms)
    c_demod_fp = sinusoidal_tracking(c_demod_fp, sample_rate, 0u"Hz")
    fp_demod = @async collect_buffers(c_demod_fp)

    # Collect raw signals as well
    iq_raw = @async collect_buffers(c)
    iq_demod = @async collect_buffers(c_demod)



    # Plot time and frequency of the last 1ms of data
    @info("Flowgraph running...")
    iq_raw = fetch(iq_raw)
    make_time_plots(iq_raw[1050*samples_1ms:1051*samples_1ms, :], names, sample_rate; title="raw")
    make_fft_plots(iq_raw[1050*samples_1ms:1051*samples_1ms, :], names, sample_rate; title="raw")

    # Next, plot demodulated signal
    iq_demod = fetch(iq_demod)
    make_time_plots(iq_demod[1050*samples_1ms:1100*samples_1ms, :], names[2:end], sample_rate; title="demod")
    make_fft_plots(iq_demod[1050*samples_1ms:1100*samples_1ms, :], names[2:end], sample_rate; title="demod")

    # Next, plot frequency and phase for raw signal
    fp = fetch(fp)
    make_FP_plots(fp[end-101:end, :], names, sample_rate; title="FP")

    # And frequency and phase for demodulated signal
    fp_demod = fetch(fp_demod)
    make_FP_plots(fp_demod[end-101:end, :], names, sample_rate; title="FP_demod")
end

main()
