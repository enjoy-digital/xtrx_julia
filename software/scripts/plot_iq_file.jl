# Don't let GR segfault
ENV["GKSwstype"] = "100"
using Plots, Statistics

function plot_complex(data, plot_file)
    plt = plot(real.(data); label="real")
    plot!(plt, imag.(data); label="imag")
    savefig(plt, plot_file)
end

for data_file in ARGS
    data = Vector{Complex{Int16}}(undef, div(filesize(data_file), sizeof(Complex{Int16})))
    open(data_file, read=true) do io
        read!(io, data)
    end
    plot_complex(data, "$(basename(data_file)).png")

    # Plot some zoomed views as well
    plot_complex(data[end-128:end], "$(basename(data_file))-tail128.png")
end
