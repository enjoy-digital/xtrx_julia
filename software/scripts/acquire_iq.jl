# configure loopback mode in the the XTRX and LMS7002M RF IC, so transmitted
# buffers should appear on the RX side.

# Don't let GR segfault
ENV["GKSwstype"] = "100"
ENV["SOAPY_SDR_LOG_LEVEL"] = "DEBUG"

using SoapySDR, Printf, Unitful, DSP
include("./libsigflow.jl")
include("./xtrx_debugging.jl")

# foreign threads can segfault us when they call back into the logger
#SoapySDR.register_log_handler()

function guess_mode(args)
    if "--lfsr-loopback" in args
        return :lfsr_loopback
    elseif "--digital-loopback" in args
        return :digital_loopback
    elseif "--tbb-loopback" in args
        return :tbb_loopback
    elseif "--trf-loopback" in args
        return :trf_loopback
    else
        return :tx
    end
end

function fpga_loopback_sanity_check(dev)
    # check that the clocks are correctly calibrated by having the FPGA
    # transmit a pattern over the digital loopback and verify the result.
    # if this fails, you might need different TX/RX delays.
    SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")
    SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_PATTERN", "1")
    SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_RX_PATTERN", "1")
    try
        e0 = unsafe_string(SoapySDR.SoapySDRDevice_readSetting(dev, "FPGA_RX_PATTERN_ERRORS"))
        sleep(0.1)
        e1 = unsafe_string(SoapySDR.SoapySDRDevice_readSetting(dev, "FPGA_RX_PATTERN_ERRORS"))
        errors = parse(Int, e1) - parse(Int, e0)
        if errors != 0
            @error "FPGA could not verify digital loopback, clock delays may need calibration!"
        end
    finally
        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_PATTERN", "0")
        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_RX_PATTERN", "0")
        SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "FALSE")
    end
end

function do_txrx(mode::Symbol;
                 register_sets::Vector{<:Pair} = Pair[],
                 dump_inis::Bool = false)
    # If we're running on pathfinder, pick a specific device
    device_kwargs = Dict{Symbol,Any}()
    if chomp(String(read(`hostname`))) == "pathfinder"
        device_kwargs[:driver] = "XTRX"
        device_kwargs[:serial] = "121c444ea8c85c"
    end

    Device(first(Devices(;device_kwargs...))) do dev
        # Get some useful parameters
        format = dev.rx[1].native_stream_format
        fullscale = dev.tx[1].fullscale

        frequency = 1575.00u"MHz"
        sample_rate = 6u"MHz"

        # Setup transmission/recieve parameters
        for (c_idx, cr) in enumerate(dev.rx)
            cr.bandwidth = sample_rate
            cr.frequency = frequency
            cr.sample_rate = sample_rate

            if mode == :tbb_loopback
                # For TBB loopback, we really don't need to be that loud
                cr[SoapySDR.GainElement(:LNA)] = 0u"dB"
                cr[SoapySDR.GainElement(:TIA)] = 0u"dB"
                cr[SoapySDR.GainElement(:PGA)] = 0u"dB"
            elseif mode == :trf_loopback
                # For :trf_loopback, we need to be a little louder
                cr[SoapySDR.GainElement(:LNA)] = 0u"dB"
                cr[SoapySDR.GainElement(:TIA)] = 0u"dB"
                cr[SoapySDR.GainElement(:PGA)] = 19u"dB"

                # We also need to enable the loopback gain
                cr[SoapySDR.GainElement(:LB_LNA)] = 40u"dB"
            elseif mode == :tx
                # For actual transmission, we need to be a little louder still
                cr[SoapySDR.GainElement(:LNA)] = 10u"dB"
                cr[SoapySDR.GainElement(:TIA)] = 12u"dB"
                cr[SoapySDR.GainElement(:PGA)] = 19u"dB"
            else
                # Default everything to absolute quiet
                cr[SoapySDR.GainElement(:LNA)] = 0u"dB"
                cr[SoapySDR.GainElement(:TIA)] = 0u"dB"
                cr[SoapySDR.GainElement(:PGA)] = -20u"dB"
            end

            # Normally, we'll be receiving from LNAL (since we're at 1.5GHz)
            # but if we're doing a TRF loopback, we need to pull from the
            # appropriate loopback path
            if mode != :trf_loopback
                cr.antenna = :LNAL
            else
                cr.antenna = Symbol("LB$(c_idx)")
            end
        end

        for ct in dev.tx
            ct.bandwidth = sample_rate
            ct.frequency = frequency
            ct.sample_rate = sample_rate

            if mode ==:tx
                # If we're actually TX'ing and RX'ing, juice it up
                ct.gain = 40u"dB"
            elseif mode == :trf_loopback
                ct.gain = 40u"dB"
            else
                # Otherwise, keep quiet
                ct.gain = 0u"dB"
            end
        end

        # Do a quick FPGA loopback sanity check for these clocking values
        fpga_loopback_sanity_check(dev)

        if mode == :digital_loopback
            SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")
        elseif mode == :lfsr_loopback
            SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE_LFSR", "TRUE")
        elseif mode == :tbb_loopback
            # Enable TBB -> RBB loopback
            SoapySDR.SoapySDRDevice_writeSetting(dev, "TBB_ENABLE_LOOPBACK", "LB_MAIN_TBB")

            # Use low bandwidth filters, and tell the RBB to use the loopback
            SoapySDR.SoapySDRDevice_writeSetting(dev, "TBB_SET_PATH", "TBB_LBF")
            SoapySDR.SoapySDRDevice_writeSetting(dev, "RBB_SET_PATH", "LB_LBF")

            # Disable RxTSP and TxTSP settings, to cause as little signal disturbance as possible
            #SoapySDR.SoapySDRDevice_writeSetting(dev, "RXTSP_ENABLE", "TRUE")
            #SoapySDR.SoapySDRDevice_writeSetting(dev, "TXTSP_ENABLE", "TRUE")
        elseif mode == :trf_loopback
            # Enable TRF -> RFE loopback
            SoapySDR.SoapySDRDevice_writeSetting(dev, "TRF_ENABLE_LOOPBACK", "TRUE")

            # Use low bandwidth filters
            SoapySDR.SoapySDRDevice_writeSetting(dev, "TBB_SET_PATH", "TBB_LBF")
            SoapySDR.SoapySDRDevice_writeSetting(dev, "RBB_SET_PATH", "LBF")

            # Disable RxTSP and TxTSP settings, to cause as little signal disturbance as possible
            #SoapySDR.SoapySDRDevice_writeSetting(dev, "RXTSP_ENABLE", "TRUE")
            #SoapySDR.SoapySDRDevice_writeSetting(dev, "TXTSP_ENABLE", "TRUE")
        end

        if !isempty(register_sets)
            @info("Applying $(length(register_sets)) register sets")
            for (addr, val) in register_sets
                if val !== nothing
                    write_lms_register(dev, addr, val)
                end
                @info(string("0x", string(addr; base=16)), value=read_lms_register(dev, addr))
            end
        end


        # Dump an initial INI, showing how the registers are configured here
        if dump_inis
            SoapySDR.SoapySDRDevice_writeSetting(dev, "DUMP_INI", "$(mode).ini")
        end

        # Construct streams
        stream_rx = SoapySDR.Stream(format, dev.rx)
        stream_tx = SoapySDR.Stream(format, dev.tx)

        # the number of buffers each stream has
        wr_nbufs = Int(SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_tx))
        rd_nbufs = Int(SoapySDR.SoapySDRDevice_getNumDirectAccessBuffers(dev, stream_rx))

        # Let's drop a few of the first buffers to skip startup effects
        drop_nbufs = 0
        if mode != :lfsr_loopback
            drop_nbufs = 4
        else
            # If we're dealing with the LFSR loopback, don't get too many buffers
            # as it takes a long time to plot randomness, and don't bother to write anything
            wr_nbufs = 0
            rd_nbufs = 4
        end

        # prepare some data to send:
        rate = 10
        num_repeats = 4
        num_channels = Int(length(dev.tx))
        mtu = Int(stream_tx.mtu)
        samples = div(mtu*wr_nbufs, num_repeats)
        t = (1:samples)./samples
        data_tx = zeros(format, num_channels, samples)

        # Create some pretty patterns to plot
        data_tx[1, :] .= format.(
            round.(sin.(2π.*t.*rate).*(fullscale/2).*0.95.*DSP.hanning(samples)),
            round.(cos.(2π.*t.*rate).*(fullscale/2).*0.95.*DSP.hanning(samples)),
        )

        # We're going to push values onto this list,
        # then concatenate them into a giant matrix at the end
        iq_data = Matrix{format}[]

        SoapySDR.activate!(stream_tx) do; SoapySDR.activate!(stream_rx) do;
            written_buffs = 0
            read_buffs = 0

            # write tx-buffer
            while written_buffs < wr_nbufs
                buffs = Ptr{format}[C_NULL]
                err, handle = SoapySDR.SoapySDRDevice_acquireWriteBuffer(dev, stream_tx, buffs, 0)
                if err == SoapySDR.SOAPY_SDR_TIMEOUT
                    break
                elseif err == SoapySDR.SOAPY_SDR_UNDERFLOW
                    err = 1 # keep going
                end
                @assert err > 0
                unsafe_copyto!(buffs[1], pointer(data_tx, mod1(num_channels*mtu*written_buffs+1, prod(size(data_tx)))), num_channels*mtu)
                SoapySDR.SoapySDRDevice_releaseWriteBuffer(dev, stream_tx, handle, 1)
                written_buffs += 1
            end

            # read/check rx-buffer
            while read_buffs < (rd_nbufs + drop_nbufs)
                buffs = Ptr{format}[C_NULL]
                err, handle, flags, timeNs = SoapySDR.SoapySDRDevice_acquireReadBuffer(dev, stream_rx, buffs, 0)

                if err == SoapySDR.SOAPY_SDR_TIMEOUT
                    continue
                elseif err == SoapySDR.SOAPY_SDR_OVERFLOW
                    err = mtu # nothing to do, should be the MTU
                end
                @assert err > 0

                if (read_buffs > drop_nbufs)
                    arr = unsafe_wrap(Matrix{format}, buffs[1], (num_channels, mtu))
                    push!(iq_data, copy(arr))
                end

                SoapySDR.SoapySDRDevice_releaseReadBuffer(dev, stream_rx, handle)
                read_buffs += 1
            end
            @show read_buffs, written_buffs
        end; end

        # Concatenate into a giant matrix, then sign-extend since it's
        # most like 12-bit signed data hiding in a 16-bit buffer:
        iq_data = cat(iq_data...; dims=2)
        sign_extend!(iq_data)

        return iq_data, data_tx
    end
end


using Plots

# Plot out received signals
function make_txrx_plots(iq_data, data_tx; name::String="data")
    plt = plot(real.(data_tx[1, :]); label="re(tx[1])", title="$(name) - Real")
    plot!(plt, real.(iq_data)[1, :]; label="re(rx[1])")
    plot!(plt, real.(iq_data)[2, :]; label="re(rx[2])")
    savefig(plt, "$(name)_re.png")

    plt = plot(imag.(data_tx[1, :]); label="im(tx[1])", title="$(name) - Imag")
    plot!(plt, imag.(iq_data)[1, :]; label="im(rx[1])")
    plot!(plt, imag.(iq_data)[2, :]; label="im(rx[2])")
    savefig(plt, "$(name)_im.png")
end

function full_loopback_suite(;kwargs...)
    @sync begin
        # First, lfsr loopback
        lfsr_iq, lfsr_tx = do_txrx(:lfsr_loopback; kwargs...)
        t_lfsr_plot = @async make_txrx_plots(lfsr_iq, lfsr_tx; name="lfsr_loopback")

        # Next, digital loopback
        digi_iq, digi_tx = do_txrx(:digital_loopback; kwargs...)
        wait(t_lfsr_plot)
        t_digi_plot = @async make_txrx_plots(digi_iq, digi_tx; name="digital_loopback")

        # Next, TBB loopback
        tbb_iq, tbb_tx = do_txrx(:tbb_loopback; kwargs...)
        wait(t_digi_plot)
        t_tbb_plot = @async make_txrx_plots(tbb_iq, tbb_tx; name="tbb_loopback")

        # Next, TRF loopback
        trf_iq, trf_tx = do_txrx(:trf_loopback; kwargs...)
        wait(t_tbb_plot)
        t_trf_plot = @async make_txrx_plots(trf_iq, trf_tx; name="trf_loopback")

        # Finally, out over the air
        tx_iq, tx_tx = do_txrx(:tx; kwargs...)
        wait(t_trf_plot)
        t_tx_plot = @async make_txrx_plots(tx_iq, tx_tx; name="tx")
    end
end


function main(args::String...)
    mode = guess_mode(args)
    dump_inis = "--dump-inis" in args
    full_suite = "--full" in args

    # You can set this here, but Elliot has changed XTRXDevice.cpp to do this automatically.
    register_sets = Pair[
        #0x00ad => 0x03f3,

        # Force CG_IAMP_TBB to be smaller, to prevent over saturating
        # Note that `0x45xx` is still large enough to saturate, but setting the IAMP
        # lower causes a bunch of noise to leak in for reasons I still don't fully understand.
        # This is probably related to the fact that most transmitters prefer to saturate.
        #0x0108 => 0x558c,
    ]

    if full_suite
        full_loopback_suite(; dump_inis, register_sets)
    else
        iq_data, data_tx = do_txrx(mode; dump_inis, register_sets)
        make_txrx_plots(iq_data, data_tx; name="$(mode)")
    end
end

isinteractive() || main(ARGS...)
