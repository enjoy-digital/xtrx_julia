# Ensure that our JLL preferences are setup properly to load our custom-built libraries
include("../julia_preferences_setup.jl")
using soapysdr_jll, SoapyLMS7_jll

REPO_ROOT = dirname(dirname(dirname(@__DIR__)))
prefix = joinpath(REPO_ROOT, "build")

if !isfile(joinpath(prefix, "bin", "LimeUtil"))
    error("You must run `make -C software limesuite`` first!")
end

plugin_env = Dict(
    # Tell `SoapySDR` how to find `libLMS7Support.so`
    "SOAPY_SDR_PLUGIN_PATH" => joinpath(prefix, "lib", "SoapySDR", "modules0.8"),
)

cd(@__DIR__) do
    run(`gcc -std=c99 soapy_limesdr_example.c -L$(prefix)/lib -Wl,-rpath,$(prefix)/lib -lSoapySDR -I$(prefix)/include -o soapy_limesdr_example`)
    run(addenv(`./soapy_limesdr_example`, plugin_env))
end
