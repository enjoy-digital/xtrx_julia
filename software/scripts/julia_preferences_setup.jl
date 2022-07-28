using Preferences

## This script is used to ensure that when we run scripts we load our locally-built libraries
## for JLLs such as `libSoapySDR.so` and `libLMS7Support.so`, etc...

REPO_ROOT = dirname(dirname(@__DIR__))
preferences_toml_path = joinpath(REPO_ROOT, "JuliaLocalPreferences.toml")

libsoapysdr_path = joinpath(REPO_ROOT, "build", "soapysdr", "lib", "libSoapySDR.so")
libLMS7Support_path = joinpath(REPO_ROOT, "build", "limesuite", "lib", "SoapySDR", "modules0.8", "libLMS7Support.so")
libLimeSuite_path = joinpath(REPO_ROOT, "build", "limesuite", "lib", "libLimeSuite.so.20.10.0")
if !all(isfile.((libsoapysdr_path, libLMS7Support_path, libLimeSuite_path)))
    error("Must run `make -C software limesuite` first!")
end

# First, set path for `libSoapySDR`:
soapysdr_jll_uuid = Base.UUID("343a40d9-ed99-5d34-8b56-649aaa4ecee6")
set_preferences!(
    preferences_toml_path,
    "soapysdr_jll",
    "libsoapysdr_path" => libsoapysdr_path;
    force=true,
)

# Next, set paths for `libLMS7Support` and `libLimeSuite`:
SoapyLMS7_jll_uuid = Base.UUID("e7ed14a0-13eb-5dc7-93e2-6133b2eb8bed")
set_preferences!(
    preferences_toml_path,
    "SoapyLMS7_jll",
    "libLMS7Support_path" => libLMS7Support_path,
    "libLimeSuite_path" => libLimeSuite_path;
    force=true,
)

# Also, manually dlopen() the `libLimeSuite`, since our ordering here is broken
# until BB properly orders `dlopen()`s
using Libdl
dlopen(libLimeSuite_path)
