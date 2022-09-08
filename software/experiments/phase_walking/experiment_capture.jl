# configure loopback mode in the the XTRX and LMS7002M RF IC, so transmitted
# buffers should appear on the RX side.

ENV["SOAPY_SDR_LOG_LEVEL"] = "DEBUG"

using SoapySDR, Printf, Unitful, DSP, Dates
include("../../scripts/libsigflow.jl")
include("../../scripts/xtrx_debugging.jl")

# Let's see if we ever over/underflow.
#set_libsigflow_verbose(true)

# We've got memory to burn, let's just not pause.
GC.enable(false)

if Threads.nthreads() < 4
    error("Must run with at least four threads!")
end

# When this is notified, the capture script exits
cleanly_exit = Base.Event()

macro try_N_times(N, ex)
    return quote
        try_idx = 0
        while true
            try_idx += 1
            try
                $(esc(ex))
                break
            catch e
                if try_idx >= $(esc(N))
                    rethrow(e)
                end
                sleep(0.1)
            end
        end
    end
end

function captures_dir(; time::DateTime = now())
    path = joinpath(
        @__DIR__,
        "captures",
        Dates.format(time, "YYYY-mm-dd-HH-MM-SS"),
    )
    mkpath(path)
    return path
end

#=
# This doesn't seem to work, I get MMAP failures when opening the stream.
function build_multi_device(serials::Vector{String})
    multi_kwargs = "driver=multi"
    for (idx, serial) in enumerate(serials)
        multi_kwargs *= ",serial[$(idx-1)]=$(serial)"
    end
    return Device(parse(KWArgs, multi_kwargs))
end
=#

function run_experiment(; dump_inis::Bool = false,
                          fpga_loopback_check::Bool = false)
    devs = collect(Devices(driver="XTRX"))

    # Open one TX device
    dev_tx = Device(first(filter(p -> p["serial"]=="134c5241b884854", devs)))

    # Open three Rx devices, identified by serial number
    rx_serials = ["1cc5241b88485c", "12cc5241b88485c", "18c5241b88485c"]
    rx_serials = rx_serials[1:2]
    #dev_rx = build_multi_device(rx_serials)
    devs_rx = Device.(filter(p -> p["serial"] in rx_serials, devs))

    # Get some useful parameters
    format = dev_tx.tx[1].native_stream_format
    fullscale = dev_tx.tx[1].fullscale

    #frequency = 1575.00u"MHz"
    frequency = 600u"MHz"
    sample_rate = 1u"MHz"

    # Setup transmission/recieve parameters
    for dev_rx in devs_rx
        # Set an integer multiple of our samplerate
        set_cgen_freq(dev_rx, 16*sample_rate)

        for cr in dev_rx.rx
            @try_N_times 3 cr.frequency = frequency
            @try_N_times 3 cr.sample_rate = sample_rate
            @try_N_times 3 cr.bandwidth = max(sample_rate, 1.5u"MHz")

            @try_N_times 3 cr.antenna = Symbol("LNAW")
            #@try_N_times 3 cr[SoapySDR.GainElement(:LNA)] = 30u"dB"
            #@try_N_times 3 cr[SoapySDR.GainElement(:TIA)] = 6u"dB"
            #@show cr[SoapySDR.GainElement(:TIA)]
            #@try_N_times 3 cr[SoapySDR.GainElement(:PGA)] = 10u"dB"
            @try_N_times 3 cr.gain = 50u"dB"
        end

        # Set the RxTSP values
        rx_tsp = RxTSPConfig()
        read!(dev_rx, rx_tsp)
        rx_tsp.enables.dc_corrector = true
        write(dev_rx, rx_tsp)
        @show rx_tsp
        @show dev_rx.rx[1]
        @show dev_rx.rx[2]
    end

    # Because of a LMS7002M-driver bug, we must divide samplerate here by 4.
    set_cgen_freq(dev_tx, 16*sample_rate/4)
    for ct in dev_tx.tx
        @try_N_times 3 ct.frequency = frequency
        @try_N_times 3 ct.sample_rate = sample_rate/4
        @try_N_times 3 ct.bandwidth = max(sample_rate, 5u"MHz")

        # If we're actually TX'ing and RX'ing, juice it up
        @try_N_times 3 ct.gain = 30u"dB"
    end

    ## Dump an initial INI, showing how the registers are configured here
    if dump_inis
        SoapySDR.SoapySDRDevice_writeSetting(dev_tx, "DUMP_INI", "experiment_xtrx0-tx.ini")
        for (idx, dev_rx) in enumerate(devs_rx)
            SoapySDR.SoapySDRDevice_writeSetting(dev_rx, "DUMP_INI", "experiment_xtrx$(idx)-rx.ini")
        end
    end

    # Construct streams
    streams_rx = [SoapySDR.Stream(format, dr.rx) for dr in devs_rx]
    stream_tx = SoapySDR.Stream(format, dev_tx.tx)
    mtu = stream_tx.mtu

    # Start receive loops
    tx_ready = Base.Event()
    threads = Task[]
    data_dir = captures_dir()
    for (idx, stream_rx) in enumerate(streams_rx)
        c_rx = membuffer(flowgate(stream_data(stream_rx, cleanly_exit), tx_ready))
        c_rx = log_stream_xfer(c_rx; title="xtrx$(idx)-rx")
        paths = [joinpath(data_dir, "xtrx$(idx)-rx$(rx_idx).sc16") for rx_idx in 1:stream_rx.nchannels]
        push!(threads, stream_data(paths, c_rx))
    end

    # Start TX loop, outputting the same pulsed sinusoid over and over again
    # Each pulse lasts 1ms
    pulse_len = div(upreferred(sample_rate).val, 1000)
    # The pulse modulates a subcarrier at 20KHz
    subcarrier_freq = 20e3
    data_tx = zeros(format, pulse_len, stream_tx.nchannels)
    t = (0:(pulse_len-1))./upreferred(sample_rate).val
    data_tx[:, 1] .= format.(
        round.(Int16, cos.(2π.*subcarrier_freq.*t) .* (fullscale/20)),
        round.(Int16, sin.(2π.*subcarrier_freq.*t) .* (fullscale/20)),
    )

    c_tx = generate_stream(pulse_len, stream_tx.nchannels; T=format) do buff
        if cleanly_exit.set
            return false
        end
        copyto!(buff, data_tx)
        return true
    end
    c_tx = rechunk(c_tx, stream_tx.mtu)
    c_tx = log_stream_xfer(c_tx; title="xtrx0-tx")
    c_tx, c_tx_archive = tee(c_tx)
    push!(threads, stream_data(stream_tx, membuffer(tripwire(c_tx, tx_ready))))

    # Tee our TX data out to disk as well
    tx_archive_paths = [
        joinpath(data_dir, "xtrx0-tx1.sc16"),
        joinpath(data_dir, "xtrx0-tx2.sc16"),
    ]
    push!(threads, stream_data(tx_archive_paths, c_tx_archive))

    # Print out if any of them exit out
    Base.errormonitor.(threads)

    # Wait for "quit"
    while true
        println("Type 'quit' to quit:")
        if readline() == "quit"
            notify(cleanly_exit)
            break
        end
    end

    @info("Gracefully quitting...")
    wait.(threads)

    return data_dir
end

function main(args::String...)
    data_dir = run_experiment(; dump_inis = "--dump-inis" in args)
    @info("Capture complete", data_dir)
end

main(ARGS...)
