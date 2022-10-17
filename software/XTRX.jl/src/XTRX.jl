module XTRX

# Straight up include our CSRs as `XTRX.CSRs.xxx`
include("CSRs_gen.jl")

# We sometimes need to call straight into the `LMS7002M-driver` codebase.
# Include some shims that make that easier.
include("LMS7002Mdriver.jl")

include("TestHarness.jl")

include("utils.jl")

end # module XTRX
