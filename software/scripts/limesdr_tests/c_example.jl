# Ensure that our JLL preferences are setup properly to load our custom-built libraries
include("../julia_preferences_setup.jl")
using soapysdr_jll, SoapyLMS7_jll

REPO_ROOT = dirname(dirname(dirname(@__DIR__)))
ss_prefix = joinpath(REPO_ROOT, "build", "soapysdr")
ls_prefix = joinpath(REPO_ROOT, "build", "limesuite")

if !isdir(ss_prefix) || !isdir(ls_prefix)
    error("You must run `make -C software limesuite`` first!")
end

plugin_env = Dict(
    # Tell `SoapySDR` how to find `libLMS7Support.so`
    "SOAPY_SDR_PLUGIN_PATH" => joinpath(ls_prefix, "lib", "SoapySDR", "modules0.8"),
    # Tell `libLMS7Support.so` how to find `libLimeSuite.so`, since it gets built with a weird RPATH
    "LD_LIBRARY_PATH" => joinpath(ls_prefix, "lib"),
)

run(`gcc -std=c99 soapy_limesdr_example.c -L$(ss_prefix)/lib -Wl,-rpath,$(ss_prefix)/lib -lSoapySDR -I$(ss_prefix)/include -o soapy_limesdr_example`)
run(addenv(`./soapy_limesdr_example`, plugin_env))
