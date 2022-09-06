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

function set_cgen_freq(dev::Device, clk_rate::Float64)
    ccall((:_ZN9SoapyXTRX18setMasterClockRateEd, libSoapyXTRX), Cvoid, (Ptr{Cvoid}, Cdouble), dev.ptr, clk_rate)
    return nothing
end
set_cgen_freq(dev::Device, clk_freq::Unitful.Frequency) = set_cgen_freq(dev, Float64(upreferred(clk_freq).val))
function get_cgen_freq(dev::Device)
    return ccall((:_ZNK9SoapyXTRX18getMasterClockRateEv, libSoapyXTRX), Cdouble, (Ptr{Cvoid},), dev.ptr)
end


function bit_set(bitpos, val, orig_val = 0x0000)
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
