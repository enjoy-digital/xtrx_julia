module CISFreqTest

# Don't let GR segfault
ENV["GKSwstype"] = "100"

# Force very verbose driver
ENV["SOAPY_SDR_LOG_LEVEL"]="DEBUG"

using XTRX, LibSigflow, FFTW, Unitful, Statistics, Plots, Printf, Test

# X-ref: https://github.com/JuliaLang/julia/pull/47128
function Base.round(::Type{Complex{T}}, z::Complex) where {T}
    Complex{T}(round(T, real(z)),
               round(T, imag(z)))
end

function cisfreqtest(;samplerate = 10u"MHz", frequency=1u"GHz", loopback_mode = XTRX.DigitalLoopback, out_dir::String="cisfreq_loopback")
    # Lock our loopback freuency to something well below nyquist, but not zero.
    f_c = samplerate/16

    config = XTRXTestConfig(;
        loopback_mode,
        rx_params = XTRX.default_rx_parameters(;samplerate, frequency),
        tx_params = XTRX.default_tx_parameters(;samplerate, frequency),
    )

    # We'll store the received data here
    local iq_data
    XTRX.run_test(config) do dev, s_tx, s_rx
        # We'll transmit for 100ms
        num_samples = round(Int, upreferred(100u"ms" * samplerate))

        # We'll transmit in 1ms buffers, so that we have perfectly periodic buffers
        # which means we can just transmit the same thing over and over again.  ;)
        samples_1ms = round(Int, upreferred(1u"ms" * samplerate))
        signal = round.(Complex{Int16},
            (2^11) .* cis.((0:(samples_1ms-1)).*upreferred(f_c/samplerate).*2π)
        )

        samples_txed = 0
        c_tx = generate_stream(samples_1ms, s_tx.nchannels; T=Complex{Int16}) do buff
            buff .= signal
            samples_txed += size(buff, 1)
            # Stop transmission if we've gone over the `num_samples` limit
            return samples_txed <= num_samples
        end
        t_tx = stream_data(s_tx, log_stream_xfer(c_tx; title="Tx"))

        # Just stream data in and concatenate together a big set of buffers
        c_rx = stream_data(s_rx, num_samples)
        iq_data = collect_buffers(log_stream_xfer(c_rx; title="Rx"))
        wait(t_tx)
    end

    # Take the FFT of the received data, ensure that it's approximately the right frequency:
    X = fft(iq_data .- mean(iq_data, dims=1), 1)

    # check that each channel has a spike in frequency at the expected location
    test_passes = true
    for channel_idx in 1:size(X,2)
        peak_idx = argmax(abs.(X[:,channel_idx]))

        # Are we more than 1 bin off?  If so, fail the test!
        ideal_peak_idx = round(Int, size(X,1) * upreferred(f_c/samplerate)) + 1
        if abs(peak_idx - ideal_peak_idx) > 2
            @error("FFT peak doesn't look so good! Potential SXT/SXR tuning mismatch, or DMA buffer corruption!",
                peak_idx,
                abs(X[peak_idx]),
                ideal_peak_idx,
                abs(X[ideal_peak_idx]),
                channel_idx,
                frequency,
                samplerate,
                loopback_mode,
            )
            test_passes = false
        end

        filename = string(
            out_dir, "/",
            test_passes ? "" : "FAIL_",
            "cisfreq_loopback_",
            @sprintf("chan%d_", channel_idx),
            @sprintf("s%.1fMHz_", Float64(uconvert(u"MHz", samplerate).val)),
            @sprintf("f%.3fGHz_", Float64(uconvert(u"GHz", frequency).val)),
            loopback_mode,
        )

        # Plot 50 points around the point of interest
        spread_idxs = 50
        f_idxs = (peak_idx-spread_idxs):(peak_idx+spread_idxs)
        if f_idxs[1] < 1
            f_idxs = f_idxs .+ (1 - f_idxs[1])
        elseif f_idxs[end] > size(X,1)
            f_idxs = f_idxs .+ (size(X,1) - 1 - f_idxs[end])
        end
        f_span = (f_idxs .- 1).*(samplerate/size(X,1))
        p = plot(f_span,
                 abs.(X[f_idxs, channel_idx]);
                 label="rx",
                 title=@sprintf("Ideal peak: %.1fMHz", Float64(uconvert(u"MHz", f_c).val))
        )
        savefig(p, "$(filename)-zoom.png")

        t_span = (0:1000) .* uconvert(u"μs", 1/samplerate)
        p = plot(t_span,
                 real.(iq_data[end-1000:end]);
                 label="real",
        )
        savefig(p, "$(filename)-time.png")

        p = plot(LinRange(-samplerate/2, samplerate/2, size(X,1)),
                 abs.(X[:, channel_idx]);
                 label="rx",
                 title=@sprintf("Ideal peak: %.1fMHz", Float64(uconvert(u"MHz", f_c).val))
        )
        savefig(p, "$(filename).png")
    end
    return test_passes
end

function run_tests()
    @testset "CIS Frequency Loopback" begin
        out_dir = "cisfreq_loopback"
        rm(out_dir; force=true, recursive=true)
        mkpath(out_dir)
        for loopback_mode in (XTRX.DigitalLoopback, XTRX.TBBLoopback, XTRX.TRFLoopback)
            @testset "$(string(loopback_mode))" begin
                for frequency in (1u"GHz", 1.5u"GHz", 2u"GHz"),
                    samplerate in (10u"MHz",)# 4u"MHz", 10u"MHz", 20u"MHz")
                    # Run the test, failures will result in a picture upload
                    @test cisfreqtest(;frequency, samplerate, loopback_mode, out_dir)
                end
            end
        end
    end
end

end # module
