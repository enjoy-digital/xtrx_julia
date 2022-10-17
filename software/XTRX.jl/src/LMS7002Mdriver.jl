module LMS7002Mdriver
using SoapySDR

# The LMS7002M-driver code is statically linked into `libSoapyXTRX`, so just use that:
const SoapyXTRXModules = joinpath(dirname(SoapySDR.soapysdr_jll.get_libsoapysdr_path()), "SoapySDR", "modules0.8")
const libSoapyXTRX = joinpath(SoapyXTRXModules, "libSoapyXTRX.so")

# Import the generated function signatures for LMS7002M-driver
include("LMS7002Mdriver_gen.jl")

# Convert an XTRXDevice pointer to a LMS7 pointer, so we can call LMS7002M-driver functions
function lms7_ptr(dev::SoapySDR.Device)
    if dev.driver != Symbol("XTRX over LitePCIe")
        throw(ArgumentError("Attempted to call XTRX private API on non-XTRX device!"))
    end
    # We love manually inlining C++-mangled function names!
    return ccall((:_ZN9SoapyXTRX13getLMS7HandleEv, libSoapyXTRX), Ptr{Cvoid}, (Ptr{Cvoid},), dev.ptr)
end

end # module LMS7002Mdriver
