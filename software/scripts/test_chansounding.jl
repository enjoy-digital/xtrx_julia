# Generate a signal for channel sounding and save it to disk.
#
# The signal consists of P sine waves. Each sine wave has duration T and is
# followed by T seconds of silence. The sine wave ramps up during the first
# 0.1T seconds and ramps down during the last 0.1T seconds.
#
# The P sine waves span a bandwidth B.
#
# A pilot with frequency F0 is added to each sine wave, to serve as a time
# reference.

""" Generate a flat raised-cosine (Tukey) window with duration T. `risetime`
specifies the rise (and fall) times as a fraction of T."""
function flatrc(T, risetime = 0.1)
    T = float(T)
    rt = risetime*T
    t -> begin
        t <= 0.0 && return 0.0
        t >= T && return 0.0
        ((t > 0.0) && (t <= rt)) && return -0.5*(cospi(t/rt))+0.5
        ((t < T) && (t >= T-rt)) && return 0.5*cospi((t-(T-rt))/rt)+0.5
        return 1.0
    end
end

"""Generate a pulsed sinusoid of duration `T`, amplitude `A`, and frequency `f0`."""
function pulsedcis(T, f0 ; A = 1.0)
    T = float(T)
    t -> begin
        t <= 0.0 && return complex(0.0, 0.0)
        t >= T && return complex(0.0, 0.0)
        return A*cispi(2*f0*t)
    end
end

"""Generate a sequence of pulsed cis signals.
`B`: bandwidth (from `-B` to `B`)
`N`: number of pulsed signals
`T`: duration of each pulse (and pause between pulses)
`f0` : fixed, reference frequency
"""
function seqpulsedcis(B, N, T, f0)
    freqs = range(start = -B, stop = B, length = N)
    window = flatrc(T)
    fs = 4*B  # a bit above Nyquist
    t = range(start = 0.0, stop = 2*N*T, step = 1/fs)
    s = zeros(ComplexF64, length(t))
    tini = 0.0
    for (idx, f) in pairs(freqs)
        pc_fixed = pulsedcis(T, f0).(t .- tini)
        pc = pulsedcis(T, f).(t .- tini)
        s .+= window.(t .- tini) .* (pc_fixed .+ pc)
        tini += 2T
    end
    return s
end

# verify if the file ends up written in the right format
function saveseq(s, filename)
    open(filename, "w") do io
        write(io, s)
    end
end
