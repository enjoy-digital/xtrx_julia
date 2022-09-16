# Ensure that our JLL preferences are setup properly to load our custom-built libraries
include("../julia_preferences_setup.jl")
include("../libsigflow.jl")

# Don't let GR try to open any windows
ENV["GKSwstype"]=100

if Threads.nthreads() < 2
    error("Must run with greater than 1 thread for full duplex transmission!")
end

using SoapySDR, SoapyLMS7_jll, Unitful, Statistics, Printf, FFTW, Plots
using SoapySDR: dB

function chirp_loopback(capture_time, freq = 2495u"MHz", fs = 1u"MHz";
                        buff_size = 128*1024, freq_points = 128)
    Device(first(Devices(parse(KWArgs, "driver=lime")))) do dev
        # Configure the channels, then open a stream of complex float32's
        for c in (dev.rx..., dev.tx...)
            c.sample_rate = fs
            c.bandwidth = fs
            c.frequency = freq
        end

        for c in (dev.rx...,)
            c.gain = 40dB
        end
        for c in (dev.tx...,)
            c.gain = 40dB
        end

        SoapySDR.Stream(ComplexF32, [dev.rx...]) do s_rx
            SoapySDR.Stream(ComplexF32, [dev.tx...]) do s_tx
                rx_ready = Base.Event()
                tx_go = Base.Event()

                # Artificially delay TX start by 0.2s to showcase synchronization
                @async begin
                    wait(rx_ready)
                    sleep(0.2)
                    notify(tx_go)
                end

                # Start streaming data from RX
                num_samples = round(Int, upreferred(fs * capture_time))
                c_psd = stream_data(s_rx, num_samples)
                c_psd = tripwire(c_psd, rx_ready; verbose=true)
                c_psd = log_stream_xfer(c_psd; title="RX")

                # Stream the RXs into PSD collections
                t_psd = Threads.@spawn collect_psd(
                    rechunk(c_psd, buff_size),
                    freq_points,
                    buff_size;
                    accumulation = :mean,
                )

                # Generate 100ms chirps spaced out a bit in time
                chirp_len = round(Int, upreferred(fs * 100u"ms"))
                num_chirp_buffs = 4
                chirp_buff_idx = 1

                # Pre-generate the chirp buffers
                tx1_chirp_buff = sin.((0:(chirp_len-1)).^2 * π / (2*chirp_len))
                tx2_chirp_buff = sin.((0:(chirp_len-1)).^2 * π / (4*chirp_len))

                c_chirp = generate_stream(chirp_len, s_tx.nchannels) do buff
                    if chirp_buff_idx % 2 == 1
                        buff[:, 1] .= tx1_chirp_buff
                        buff[:, 2] .= ComplexF32(0.0, 0.0)
                    else
                        buff[:, 1] .= ComplexF32(0.0, 0.0)
                        buff[:, 2] .= tx2_chirp_buff
                    end
                    chirp_buff_idx += 1
                    return chirp_buff_idx <= num_chirp_buffs
                end

                # Stream the chirps out to the TX
                c_chirp = log_stream_xfer(c_chirp; title="TX")
                c_chirp = rechunk(c_chirp, s_tx.mtu)
                t_tx = stream_data(s_tx, flowgate(c_chirp, tx_go; verbose=true))

                # Wait for TX to finish
                wait(t_tx)

                # Wait for our RX to finish
                return fetch(t_psd)
            end
        end
    end
end

function plot_psds(psds, capture_time, freq, fs)
    plots = []
    for channel_idx in 1:size(psds,3)
        psd = view(psds, :, :, channel_idx)
        title_args = ()
        if channel_idx == 1
            title_args = (;title = "MIMO Chirp signal test")
        end
        push!(plots, heatmap(
            # Time in seconds
            LinRange(0, uconvert(u"s", capture_time).val, size(psd,2)),
            # Frequency, in hertz
            LinRange(uconvert(u"MHz", freq - fs/2).val, uconvert(u"MHz", freq + fs/2).val, size(psd, 1)),
            # power spectral density
            log.(psd);
            xlabel = "rx[$(channel_idx)] - Time (s)",
            ylabel = "Frequency (MHz)",
            title_args...,
        ))
    end

    p = plot(
        plots...,
        layout=(length(plots), 1),
    )
    filename = @sprintf(
        "chirp_loopback_%.3fGHz_%ds.png",
        uconvert(u"GHz", freq).val,
        uconvert(u"s", capture_time).val,
    )
    savefig(p, filename)
    return nothing
end

# Do the chirp loopback
capture_time = 1u"s"
freq = 2495u"MHz"
fs = 10u"MHz"

# Do one loopback first, to get compilation rolling
chirp_loopback(capture_time, freq, fs)
psds = chirp_loopback(capture_time, freq, fs)

# Plot out both channels
plot_psds(psds, capture_time, freq, fs)
