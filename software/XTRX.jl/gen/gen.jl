#! /usr/bin/env julia

using Clang.Generators

include_dir = joinpath(@__DIR__, "../../litepcie-kernel-module/") |> normpath
options = load_options(joinpath(@__DIR__, "generator.toml"))

# add compiler flags, e.g. "-DXXXXXXXXX"
args = get_default_args()
headers = joinpath.(include_dir, ["csr.h", "soc.h", "mem.h", "config.h"])

# create context
ctx = create_context(headers, args, options)

# run generator
build!(ctx)
