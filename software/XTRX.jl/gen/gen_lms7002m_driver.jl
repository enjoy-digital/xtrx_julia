#! /usr/bin/env julia

## This script generates the LMS7002M_constants.jl file, which contains 
using Clang.Generators

options = load_options(joinpath(@__DIR__, "gen_lms7002m_driver.toml"))

# add compiler flags, e.g. "-DXXXXXXXXX"
driver_include_dir = joinpath(@__DIR__, "../../LMS7002M-driver/include/") |> normpath
args = get_default_args()
push!(args, "-I$(driver_include_dir)")


# Point it to the headers in this repository
headers = [
    joinpath(driver_include_dir, "LMS7002M/LMS7002M.h"),
]
ctx = create_context(headers, args, options)
build!(ctx)
