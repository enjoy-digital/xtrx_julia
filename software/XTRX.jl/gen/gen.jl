#! /usr/bin/env julia

using Clang.Generators

include_dir = joinpath(@__DIR__, "../../litepcie-kernel-module/") |> normpath
options = load_options(joinpath(@__DIR__, "generator.toml"))

options["general"]["output_file_path"] = joinpath(@__DIR__, "../src/XTRX.jl")

@show options

# add compiler flags, e.g. "-DXXXXXXXXX"
args = get_default_args()
@show args

headers = joinpath.(include_dir, ["csr.h", "soc.h", "mem.h", "config.h"])
@show headers

# create context
@show options
ctx = create_context(headers, args, options)

# run generator
build!(ctx)