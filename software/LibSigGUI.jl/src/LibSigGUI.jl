module LibSigGUI

using LibSigflow, Makie, DSP, FFTW

export plot_periodograms, plot_signal, open_and_display_figure

function open_and_display_figure(;use_button = true)
    fig = Figure()
    display(fig)
    close_stream_event = Base.Event()
    if use_button
        fig[1, 1] = buttongrid = GridLayout(tellwidth = false)
        button = buttongrid[1, 1] = Button(fig, label = "Stop")
        on(button.clicks) do n
            notify(close_stream_event)
        end
    end
    on(events(fig.scene).window_open) do event
        if !event
            notify(close_stream_event)
        end
    end
    fig, close_stream_event
end

function plot_periodograms(in::VectorSizedChannel{T}; fig) where T <: DSP.Periodograms.Periodogram
    points_foreach_channel = [Observable(Point2f0.([-1.0, 1.0], [0.0, 0.0])) for _ = 1:in.num_antenna_channels]
    ax_offset = length(fig.content)
    axs = map(points_foreach_channel, 1:in.num_antenna_channels) do points, idx
        ax, l = lines(fig[idx + ax_offset, 1], points, axis = (
            xlabel = "Frequency (MHz)",
            ylabel = "Signal power (dB)",
            title = "Channel $idx"
            )
        )
        return ax
    end

    consume_channel(in) do periodograms
#        if isopen(fig.scene) # Does not work for WGLMakie
            foreach(periodograms, points_foreach_channel, axs) do periodogram, points, ax
                points[] = Point2f0.(
                    fftshift(freq(periodogram) ./ 1e6),
                    fftshift(10*log10.(power(periodogram)))
                )
                autolimits!(ax)
#            end
        end
    end
end

function plot_signal(in::AbstractSizedChannel; fig, ylabel = "Signal amplitude")
    points_foreach_channel = [Observable(Point2f0.([-1.0, 1.0], [0.0, 0.0])) for _ = 1:in.num_antenna_channels]
    ax_offset = length(fig.content)
    axs = map(points_foreach_channel, 1:in.num_antenna_channels) do points, idx
        ax, l = lines(fig[idx + ax_offset, 1], points, axis = (
                xlabel = "Samples",
                ylabel = ylabel,
                title = "Channel $idx"
            )
        )
        return ax
    end

    consume_channel(in) do signals
#        if isopen(fig.scene) # Does not work for WGLMakie
            foreach(signals isa Matrix ? eachcol(signals) : signals, points_foreach_channel, axs) do signal, points, ax
                num_samples = length(signal)
                points[] = Point2f0.(0:num_samples - 1, signal)
                autolimits!(ax)
            end
#        end
    end
end

end # module LibSigGUI
