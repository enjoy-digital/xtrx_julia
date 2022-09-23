using Statistics, FFTW

function sinusoidal_relative_error(data)
    D = fft(data)

    # De-mean our signal
    D[1] *= 0

    # Collect overall signal energy
    total_energy = sum(abs2, D)

    # Remove the largest sinusoidal component
    D[argmax(abs.(D))] *= 0

    # Return the left over signal energy
    return sum(abs2, D)/total_energy
end

function do_analysis(data_file; buff_len = 1024)
    # We'll analyze time windows of `buff_len`.  Because we overlap our windows
    # by 50%, we actually read in `buff_len/2` samples each time:
    read_buffs = (
        Vector{Complex{Int16}}(undef, div(buff_len,2)),
        Vector{Complex{Int16}}(undef, div(buff_len,2))
    )
    pass = true
    num_half_buffs = div(filesize(data_file), div(buff_len,2)*sizeof(eltype(read_buffs[1])))
    max_rel_err = 0
    open(ARGS[1], read=true) do io
        read!(io, read_buffs[1])
        for buff_idx in 2:num_half_buffs
            # Swap our buffers, read into this half
            read_buffs = (read_buffs[2], read_buffs[1])
            read!(io, read_buffs[1])

            # If we ever have greater than 10% error, complain
            data = vcat(read_buffs[1], read_buffs[2])
            rel_err = sinusoidal_relative_error(data)
            max_rel_err = max(0, rel_err)
            if rel_err > 0.1
                @error("Bad fit detected", data_file, time_window = (buff_idx*div(buff_len,2)):((buff_idx+2)*div(buff_len,2)), rel_err)
                pass = false
            end
        end
    end
    @info("Processed $(num_half_buffs*div(buff_len,2)) samples", max_rel_err)
    return pass
end

for file in ARGS
    if !do_analysis(file)
        exit(1)
    end
end
