using Unitful

# Debugging register poking API.  This is very unportable
const SoapyXTRXModules =
    get(ENV, "SOAPY_SDR_PLUGIN_PATH",
        joinpath(dirname(SoapySDR.soapysdr_jll.get_libsoapysdr_path()), "SoapySDR", "modules0.8"))
const libSoapyXTRX = joinpath(SoapyXTRXModules, "libSoapyXTRX.so")
function write_lms_register(dev::Device, addr::UInt16, value::UInt16)
    ccall((:_ZN9SoapyXTRX13writeRegisterEjj, libSoapyXTRX), Cvoid, (Ptr{Cvoid}, Cuint, Cuint), dev.ptr, addr, value)
    return nothing
end
function read_lms_register(dev::Device, addr::UInt16)
    return UInt16(ccall((:_ZNK9SoapyXTRX12readRegisterEj, libSoapyXTRX), Cuint, (Ptr{Cvoid}, Cuint), dev.ptr, addr))
end

function set_mac(dev::Device, channels::Symbol)
    enable_A = channels ∈ (:A, :AB)
    enable_B = channels ∈ (:B, :AB)
    ccall((:_ZN9SoapyXTRX16writeMACregisterEjj, libSoapyXTRX), Cvoid, (Ptr{Cvoid}, Cint, Cint), dev.ptr, Cint(enable_A), Cint(enable_B))
    return nothing
end

function set_cgen_freq(dev::Device, clk_rate::Float64)
    ccall((:_ZN9SoapyXTRX18setMasterClockRateEd, libSoapyXTRX), Cvoid, (Ptr{Cvoid}, Cdouble), dev.ptr, clk_rate)
    return nothing
end
function set_cgen_freq(dev::Device, freq::Unitful.Frequency)
    return set_cgen_freq(dev, Float64(upreferred(freq).val))
end
function get_cgen_freq(dev::Device)
    return ccall((:_ZNK9SoapyXTRX18getMasterClockRateEv, libSoapyXTRX), Cdouble, (Ptr{Cvoid},), dev.ptr)
end

function get_bit(bitpos, val)
    return Bool((val & (0x1 << bitpos)) >> bitpos)
end

function set_bit(bitpos, val, orig_val = 0x0000)
    return UInt16(val << bitpos | (orig_val & ~(1 << bitpos)))
end


#=
# This code was used to discover that setting:
#  - CDSN_RXBLML = 0
#  - CDSN_RXALML = 0
# was necessary to get the TBB loopback looking right, e.g.
# without giant spikes at the zero crossings.

function gen_reg_0x00ad(CDS_MCLK2, CDS_MCLK1, inversions)
    return UInt16(
        CDS_MCLK2 << 14 | CDS_MCLK1 << 12 | 0x0300 | inversions
    )
end

function gen_clock_scan_register_sets()
    register_sets = Vector{Vector{Pair{UInt16,UInt16}}}()
    for cds_mclk2 in 0:3, cds_mclk1 in 0:3, inversions in [0xff & ~(0x1 << idx) for idx in 0:7]
        push!(register_sets, [0x00ad => gen_reg_0x00ad(cds_mclk2, cds_mclk1, inversions)])
    end
    return register_sets
end

function do_clock_scan(kwargs...)
    for register_sets in gen_clock_scan_register_sets()
        iq_data, data_tx = do_txrx(; tbb_loopback=true, register_sets, kwargs...)
        N = 800
        K = 20000
        make_txrx_plots(iq_data[:, K:K+N], data_tx[:, K:K+N])
        println("waiting...")
        readline()
        GC.gc()
    end
end
=#

mutable struct RxTSPComponentEnables
    dc_tracking_loop::Bool
    CMIX::Bool
    AGC::Bool
    GFIR3::Bool
    GFIR2::Bool
    GFIR1::Bool
    dc_corrector::Bool
    gain_corrector::Bool
    phase_corrector::Bool
end

RxTSPComponentEnables() = RxTSPComponentEnables(false, false, false, false, false, false, false, false, false)

function deserialize(reg::UInt16)
    x = RxTSPComponentEnables(
        # DCLOOP_STOP
        !get_bit(8, reg),
        # CMIX_BYP
        !get_bit(7, reg),
        # AGC_BYP
        !get_bit(6, reg),
        # GFIR3_BYP
        !get_bit(5, reg),
        # GFIR2_BYP
        !get_bit(4, reg),
        # GFIR1_BYP
        !get_bit(3, reg),
        # DC_BYP
        !get_bit(2, reg),
        # GC_BYP
        !get_bit(1, reg),
        # PH_BYP
        !get_bit(0, reg),
    )
    return x
end

function serialize(rtcp::RxTSPComponentEnables)
    return UInt16(
        set_bit(8, !rtcp.dc_tracking_loop) |
        set_bit(7, !rtcp.CMIX) |
        set_bit(6, !rtcp.AGC) |
        set_bit(5, !rtcp.GFIR3) |
        set_bit(4, !rtcp.GFIR2) |
        set_bit(3, !rtcp.GFIR1) |
        set_bit(2, !rtcp.dc_corrector) |
        set_bit(1, !rtcp.gain_corrector) |
        set_bit(0, !rtcp.phase_corrector)
    )
end

mutable struct RxTSPConfig
    enables::RxTSPComponentEnables
end
RxTSPConfig() = RxTSPConfig(RxTSPComponentEnables())

function Base.show(io::IO, rx_tsp::RxTSPConfig)
    println(io, "RxTSPConfig")
    println(io, "  Enabled stages:")
    for field in (:dc_corrector, :dc_tracking_loop, :gain_corrector, :phase_corrector, :CMIX, :AGC, :GFIR1, :GFIR2, :GFIR3)
        if getfield(rx_tsp.enables, field)
            println(io, "    - $(field)")
        end
    end
end

function Base.read!(dev::Device, rx_tsp::RxTSPConfig)
    # We just always read from channel A
    set_mac(dev, :A)
    rx_tsp.enables = deserialize(read_lms_register(dev, 0x040C))
    return rx_tsp
end

function Base.write(dev::Device, rx_tsp::RxTSPConfig)
    for channel in (:A, :B)
        # Read back the other configuration bits:
        set_mac(dev, channel)
        reg = read_lms_register(dev, 0x040C)

        # Insert our new RxTSPConfig values
        reg = (reg & 0xfe00) | serialize(rx_tsp.enables)
        write_lms_register(dev, 0x040C, reg)
    end
end
