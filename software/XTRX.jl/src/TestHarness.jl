using LibSigflow, SoapySDR, Unitful

export XTRXTestConfig, XTRXChannelParameters, XTRXRxFilterConfig, XTRXTxFilterConfig
export run_test

## This file contains helper methods for building XTRX tests.
## We build here APIs for opening and closing XTRX devices, configuring them in various
## loopback situations, analyzing the received signal, determining statistics about 


@enum XTRXRxFilterConfig begin
    # Use whatever the driver thinks is best
    RxFilterAuto
    # Low bandwidth filter, used for samplerates < 18MHz
    RxFilterLowBandwidth
    # High bandwidth filter, used for samplerates < 80MHz
    RxFilterHighBandwidth
    # Bypass filter, only recommended for loopback testing
    RxFilterBypass
end

@enum XTRXTxFilterConfig begin
    # Use whatever the driver thinks is best
    TxFilterAuto
    # Low bandwidth filter, used for samplerates < 20MHz
    TxFilterLowBandwidth
    # High bandwidth filter, used for samplerates < 80MHz
    TxFilterHighBandwidth
    # Bypass filter, only recommended for loopback testing
    TxFilterBypass

    # There are more options, such as isolating a single filter (lad, s5, etc...)
    # we're not going to bother with isolating them for now.
end


"""
    XTRXChannelParameters

Set the channel parameters such as carrier frequency, samplerate, filter bandwidth, etc...
"""
struct XTRXChannelParameters
    frequency::Unitful.Frequency
    samplerate::Unitful.Frequency
    bandwidth::Unitful.Frequency
    gains::Dict{Symbol,Unitful.Gain}
    antenna::Symbol

    function XTRXChannelParameters(frequency, samplerate, bandwidth, gains, antenna)
        return new(
            upreferred(frequency),
            upreferred(samplerate),
            upreferred(bandwidth),
            Dict(Symbol(k) => upreferred(v) for (k, v) in gains),
            Symbol(antenna),
        )
    end
end

# Create "default" values for RX and TX
function default_rx_parameters(;frequency = 1u"GHz",
                                samplerate = 10u"MHz",
                                bandwidth = 10u"MHz",
                                gains = Dict(:LNA => 30u"dB", :TIA => 9u"dB", :PGA => 6u"dB"),
                                antenna = :LNAW)
    return XTRXChannelParameters(frequency, samplerate, bandwidth, gains, antenna)
end
function default_tx_parameters(;frequency = 1u"GHz",
                                samplerate = 10u"MHz",
                                bandwidth = 10u"MHz",
                                gains = Dict(:PAD => 0u"dB"),
                                antenna = :BAND1)
    return XTRXChannelParameters(frequency, samplerate, bandwidth, gains, antenna)
end

function configure_channel!(channel::SoapySDR.Channel, params::XTRXChannelParameters)
    channel.frequency = params.frequency
    channel.sample_rate = params.samplerate
    channel.bandwidth = params.bandwidth
    for (gain_name, gain_val) in params.gains
        channel[SoapySDR.GainElement(gain_name)] = gain_val
    end
    channel.antenna = params.antenna
end


"""
    XTRXLoopbackMode

Often, when running a test, we'll probe different parts of the XTRX by enabling
different loopbacks, so as to isolate different parts of the system.
"""
@enum XTRXLoopbackMode begin
    # Don't even enter the LMS7002M chip, just loop back at the DMA subsystem
    DMALoopback
    # Enter the LMS7002M chip, but loop back before we enter the TSP system
    DigitalLoopback
    # Enter the the LMS7002M's transceiver signal processor, engage in filtering and whatnot,
    # then loop back before getting modulated up to the target frequency.
    TBBLoopback
    # Pass far enough to be modulated up to RF, but don't actually go out onto the wire
    TRFLoopback
    # No loopback, actually transmit out onto the wire
    NoLoopback
end

# Normally, the soapysdr-xtrx driver configures its own filter path as needed,
# but during tests we sometimes prefer explicit settings.
function configure_filter_path!(dev::SoapySDR.Device, filter_path::XTRXRxFilterConfig,
                                rx_params::XTRXChannelParameters, loopback_mode::XTRXLoopbackMode)
    filter_path_name = ""
    
    if filter_path == RxFilterAuto
        # If we're doing a TBB loopback, we need to manually enable the special loopback pathways
        # We do so by manually selecting the correct filter path here, and then later the name
        # of the selected filter path will be adjusted to be a loopback path.
        if loopback_mode == TBBLoopback
            if rx_params.bandwidth > 18u"MHz"
                filter_path = RxFilterHighBandwidth
            else
                filter_path = RxFilterLowBandwidth
            end
        else
            # Otherwise do nothing; `RxFilterAuto` means "let the driver decide"
            return
        end
    end

    if filter_path == RxFilterLowBandwidth
        filter_path_name = "LBF"
    elseif filter_path == RxFilterHighBandwidth
        filter_path_name = "HBF"
    elseif filter_path == RxFilterBypass
        filter_path_name = "BYPASS"
    else
        # Guard against future pathway inclusions
        error("Unknown RX filter type $(filter_path)")
    end

    # TBB Loopback pathways feed our RBB filters differently than the typical
    # pathway; we denote those by prepending `LB_` to the filter pathway name
    if loopback_mode == TBBLoopback
        filter_path_name = string("LB_", filter_path_name)
    end
    SoapySDR.SoapySDRDevice_writeSetting(dev, "RBB_SET_PATH", filter_path_name)
end

function configure_filter_path!(dev::SoapySDR.Device, filter_path::XTRXTxFilterConfig)
    filter_path_name = ""

    if filter_path == TxFilterAuto
        return
    elseif filter_path == TxFilterLowBandwidth
        filter_path_name = "LBF"
    elseif filter_path == TxFilterHighBandwidth
        filter_path_name = "HBF"
    elseif filter_path == TxFilterBypass
        filter_path_name = "BYPASS"
    else
        # Guard against future pathway inclusions
        error("Unknown TX filter type $(filter_path)")
    end

    # TODO: Re-name this to no longer have `TBB_` at the front, to be consistent with Rx
    filter_path_name = string("TBB_", filter_path_name)    
    SoapySDR.SoapySDRDevice_writeSetting(dev, "TBB_SET_PATH", filter_path_name)
end

function configure_loopback!(dev::SoapySDR.Device, mode::XTRXLoopbackMode, )
    if mode == DMALoopback
        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_DMA_LOOPBACK_ENABLE", "TRUE")
    elseif mode == DigitalLoopback
        SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")
    # Disable this for now, not sure this really belongs here
    #elseif mode == LFSRLoopback
    #    SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE_LFSR", "TRUE")
    elseif mode == TBBLoopback
        # Enable TBB -> RBB loopback
        SoapySDR.SoapySDRDevice_writeSetting(dev, "TBB_ENABLE_LOOPBACK", "LB_MAIN_TBB")
    elseif mode == TRFLoopback
        # Enable TRF -> RFE loopback
        SoapySDR.SoapySDRDevice_writeSetting(dev, "TRF_ENABLE_LOOPBACK", "TRUE")
    elseif mode == NoLoopback
        # Do nothing, assume the device came up normally
    end
end


struct XTRXTestConfig
    # Arguments to specify which device to connect to (e.g. serial number, or dev node, etc...)
    # We'll open the first device to match the given specification.
    device::Dict{Symbol,String}

    # Often, when running a test, we'll want to do it in some kind of loopback mode
    loopback_mode::XTRXLoopbackMode

    # Define the parameters of the channels used in the test.
    # Note that while we allow rx and tx to have separate parameters (mostly for the gains)
    # we will still enforce that samplerates are locked between them.
    rx_params::XTRXChannelParameters
    tx_params::XTRXChannelParameters
    rx_filter_path::XTRXRxFilterConfig
    tx_filter_path::XTRXTxFilterConfig

    function XTRXTestConfig(;
                            device::Dict = Dict(),
                            loopback_mode::XTRXLoopbackMode = NoLoopback,
                            rx_params::XTRXChannelParameters = default_rx_parameters(),
                            tx_params::XTRXChannelParameters = default_tx_parameters(),
                            rx_filter_path = RxFilterAuto,
                            tx_filter_path = TxFilterAuto,
                            )
        # We only support the XTRX driver, so make sure that's set correctly
        device = Dict(Symbol(k) => string(v) for (k, v) in device)
        device[:driver] = "XTRX"

        # Ensure rx and tx parameters are coherent
        if rx_params.samplerate != tx_params.samplerate
            throw(ArgumentError("TX/RX sample rates must match!"))
        end

        return new(
            device,
            loopback_mode,
            rx_params,
            tx_params,
            rx_filter_path,
            tx_filter_path
        )
    end
end

# Select the first device that matches the given arguments
SoapySDR.Device(config::XTRXTestConfig) = Device(first(Devices(;config.device...)))

function configure_channels!(dev::SoapySDR.Device, config::XTRXTestConfig)
    for c in dev.rx
        configure_channel!(c, config.rx_params)
    end
    for c in dev.tx
        configure_channel!(c, config.tx_params)
    end
end

"""
    run_test(flowgraph_generator::Function, config::XTRXTestConfig)

Harness to run a test for the XTRX, given a particular `XTRXTestConfig`, using
the provided `flowgraph_generator` function, which is provided the `SoapySDR.Device`,
and two `SoapySDR.Stream` objects representing the tx/rx pair for the test.
"""
function run_test(run_flowgraph::Function, config::XTRXTestConfig)
    # Get the device
    dev = Device(config)

    # Configure its channels appropriately
    configure_channels!(dev, config)

    # Set up loopback and filter path selection
    configure_loopback!(dev, config.loopback_mode)
    configure_filter_path!(dev, config.rx_filter_path, config.rx_params, config.loopback_mode)
    configure_filter_path!(dev, config.tx_filter_path)

    # Open our streams
    stream_rx = SoapySDR.Stream(dev.rx)
    stream_tx = SoapySDR.Stream(dev.tx)
    
    # Reset LibSigflow statistics
    LibSigflow.reset_xflow_stats()

    try
        # The flowgraph generator receives our rx and tx streams, as well as the device itself:
        run_flowgraph(dev, stream_tx, stream_rx)
    finally
        # Ensure the streams and devices are closed properly
        finalize(stream_rx)
        finalize(stream_tx)
        finalize(dev)
    end

    xflow_stats = LibSigflow.get_xflow_stats()
    return xflow_stats
end
