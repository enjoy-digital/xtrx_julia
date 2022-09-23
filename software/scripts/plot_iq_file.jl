# Don't let GR segfault
ENV["GKSwstype"] = "100"
using Plots, Statistics

function plot_cisoid(data, plot_file)
    cisoid = cisoid_fit(data)
    plt = plot(real.(data); label="real", title="$(data_file)")
    plot!(plt, imag.(data); label="imag")
    plot!(plt, real.(cisoid); label="real(cisoid)")
    plot!(plt, imag.(cisoid); label="imag(cisoid)")
    savefig(plt, plot_file)
end

function plot_complex(data, plot_file)
    plt = plot(real.(data); label="real", title="$(data_file)")
    plot!(plt, imag.(data); label="imag")
    savefig(plt, plot_file)
end

data = Vector{Complex{Int16}}(undef, 4_000_000)
function plot_iq_file(data_file, plot_file)
    samples_read = 0
    open(data_file, read=true) do io
        read!(io, data)
    end

    plot_complex(data, plot_file)
end

function Base.round(::Type{Complex{Int16}}, x::ComplexF64)
    return Complex(
        round(Int16, x.re),
        round(Int16, x.im),
    )
end

function cisoid_fit(data; ω_fit_len = 200000, ϕ_fit_len = 100, angle_skip = 100000)
    # Determine that slow rotation rate
    ω = angle(mean(data[1+angle_skip:ω_fit_len+angle_skip] ./ data[1:ω_fit_len]))/angle_skip

    # Determine I/Q offset, and magnitude by summing over a whole cycle
    cycle_len = ceil(Int, abs(2π/ω))
    μ = mean(data[1:cycle_len])
    α = mean(abs.(data[1:cycle_len]))

    # Get initial phase estimate
    ϕ = angle(mean(data[1:ϕ_fit_len]))

    return round.(Complex{Int16}, μ .+ α.*cis.((0:(length(data)-1)).*ω .+ ϕ))
end

data_file = ARGS[1]
plot_file = get(ARGS, 2, "$(basename(ARGS[1])).png")
plot_iq_file(data_file, plot_file)
