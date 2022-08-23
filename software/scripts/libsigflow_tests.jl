using Test, FFTW
include("libsigflow.jl")

# Set ourselves to be verbose for the tests sometimes
#set_libsigflow_verbose(true)

function verify_test_pattern_buffer(buff, idx, buff_size)
    @test length(buff) == buff_size
    @test real(buff[1]) == imag(buff[1])
    @test real(buff[end]) == buff_size*idx
    @test real(buff[1]) == buff_size*(idx-1) + 1
end

@testset "generate_test_pattern" begin
    num_samples = 32
    c = generate_test_pattern(num_samples)
    verify_test_pattern_buffer(take!(c), 1, num_samples)
    sleep(0.001)
    @test !isopen(c)

    c = generate_test_pattern(num_samples; num_buffers=2)
    verify_test_pattern_buffer(take!(c), 1, num_samples)
    verify_test_pattern_buffer(take!(c), 1, num_samples)
    sleep(0.001)
    @test !isopen(c)
end

@testset "tee" begin
    num_samples = 32
    c1, c2 = tee(generate_test_pattern(num_samples))
    for c in (c1, c2)
        buff = take!(c)
        verify_test_pattern_buffer(buff, 1, num_samples)
    end
    sleep(0.001)
    @test !isopen(c1)
    @test !isopen(c2)
end

@testset "flowgate" begin
    num_samples = 32
    ctl = Base.Event()
    waiting = Base.Event()
    c = flowgate(generate_test_pattern(num_samples), ctl)
    t_take = @async begin
        t_start = time()
        notify(waiting)
        take!(c)
        return time() - t_start
    end

    wait(waiting)
    sleep(0.01)
    notify(ctl)
    @test fetch(t_take) > 0.01
    @test !isopen(c)
end

@testset "tripwire" begin
    num_samples = 32
    ctl = Base.Event()
    c = tripwire(generate_test_pattern(num_samples), ctl)
    consume_channel(c) do buff
    end
    @test ctl.set
    @test !isopen(c)
end

@testset "rechunk" begin
    # First, test rechunking to twice the size
    @testset "x -> 2x" begin
        num_samples = 32
        c_small, c_large = tee(generate_test_pattern(num_samples))
        buff_size = 4
        c_small = rechunk(c_small, buff_size)
        c_large = rechunk(c_large, buff_size*2)
        for idx in 1:div(num_samples, buff_size*2)
            buff_small_0 = take!(c_small)
            buff_small_1 = take!(c_small)
            buff_large = take!(c_large)

            @test vcat(buff_small_0, buff_small_1) == buff_large
        end
        sleep(0.001)
        @test !isopen(c_small)
        @test !isopen(c_large)
    end

    # Next, test rechunking to odd, non-overlapping sizes in a chain:
    @testset "x -> y -> z" begin
        buff_size = 10240
        first_buff_size = 8
        last_buff_size = 7
        c = rechunk(rechunk(generate_test_pattern(buff_size), first_buff_size), last_buff_size)
        for idx in 1:div(buff_size, last_buff_size)
            buff = take!(c)
            verify_test_pattern_buffer(buff, idx, last_buff_size)
        end
        sleep(0.001)
        @test !isopen(c)
    end

    @testset "8160 -> 400" begin
        buff_size = 8160
        new_buff_size = 400
        c = rechunk(generate_test_pattern(buff_size), new_buff_size)
        for idx in 1:div(buff_size, new_buff_size)
            buff = take!(c)
            verify_test_pattern_buffer(buff, idx, new_buff_size)
        end
        sleep(0.001)
        @test !isopen(c)
    end

    @testset "multichannel" begin
        c = rechunk(generate_test_pattern(8; num_channels = 2), 4)
        buff = take!(c)
        @test size(buff) == (4, 2)
        @test buff[1, 1] == ComplexF32(1, 1)
        buff = take!(c)
        @test size(buff) == (4, 2)
        @test buff[1, 1] == ComplexF32(5, 5)
        sleep(0.001)
        @test !isopen(c)
    end
end

@testset "generate_chirp" begin
    num_samples = 1024
    c = generate_chirp(num_samples)
    buff = take!(c)
    @test size(buff) == (1024, 1)

    # Test that the FFT of the first half is weighted in `[0, fs/4]`
    # and the second half is weighted in `[0, fs/2]`:
    BUFF1 = abs.(fft(buff[1:div(end,2), 1])[1:div(end,2)])
    BUFF2 = abs.(fft(buff[div(end,2)+1:end, 1])[1:div(end,2)])
    @test    sum(BUFF1[1:div(end,2)]) > 10*sum(BUFF1[div(end,2)+1:end])
    @test 10*sum(BUFF2[1:div(end,2)]) <    sum(BUFF2[div(end,2)+1:end])
end

# Now do the same thing, but using the `stft()` block:
@testset "stft" begin
    num_samples = 1024
    buff_size = div(num_samples,2)
    c = stft(rechunk(generate_chirp(num_samples), buff_size))
    BUFF1 = abs.(take!(c)[1:div(end, 2), 1])
    BUFF2 = abs.(take!(c)[1:div(end, 2), 1])
    @test    sum(BUFF1[1:div(end,2)]) > 10*sum(BUFF1[div(end,2)+1:end])
    @test 10*sum(BUFF2[1:div(end,2)]) <    sum(BUFF2[div(end,2)+1:end])
end

# Finally, use `absshift` as well
@testset "absshift" begin
    num_samples = 1024
    buff_size = div(num_samples,2)
    c = absshift(stft(rechunk(generate_chirp(num_samples), buff_size)))
    BUFF1 = take!(c)[div(end, 2)+1:end, 1]
    BUFF2 = take!(c)[div(end, 2)+1:end, 1]
    @test    sum(BUFF1[1:div(end,2)]) > 10*sum(BUFF1[div(end,2)+1:end])
    @test 10*sum(BUFF2[1:div(end,2)]) <    sum(BUFF2[div(end,2)+1:end])
end

@testset "reduce" begin
    num_samples = 32
    # Test summation reduction
    c = reduce(generate_test_pattern(num_samples; num_buffers=4), 2) do buffs
        verify_test_pattern_buffer(buffs[:, 1, 1], 1, num_samples)
        verify_test_pattern_buffer(buffs[:, 1, 2], 1, num_samples)
        return sum(buffs, dims=3)[:,:, 1]
    end
    @test take!(c) == 2*take!(generate_test_pattern(num_samples))
    @test take!(c) == 2*take!(generate_test_pattern(num_samples))
    sleep(0.001)
    @test !isopen(c)
end

@testset "log_stream_xfer" begin
    buff_size = 8
    c = rechunk(generate_test_pattern(buff_size*3), buff_size)

    # Artificially choke the `log_stream_xfer`'s output so that it is forced to print.
    print_period = 0.1
    @test_logs (:info, r"Xfer") begin
        c = log_stream_xfer(c; print_period)
        buff = take!(c)
        @test length(buff) == buff_size
        sleep(print_period)
        buff = take!(c)
        @test length(buff) == buff_size
        buff = take!(c)
        @test length(buff) == buff_size
    end
end

@testset "collect_psd" begin
    chirp_len = 1024
    buff_size = 128
    freq_res = 32
    PSD = collect_psd(rechunk(generate_chirp(chirp_len), buff_size), freq_res, buff_size)
    @test size(PSD) == (32, 8, 1)

    # Throw away the negative frequencies and channel index
    PSD = PSD[div(end,2):end, :, 1]

    # Ensure that we see a chirp rising in frequency
    for idx in 1:size(PSD,2)
        @test sum(PSD[(idx-1)*2+2:idx*2+1, idx]) > 5*sum(PSD[:, idx])/size(PSD,1)
    end
end

@testset "sign_extend" begin
    sig = vcat(
        [Complex{Int16}(idx,        4096 - idx) for idx in 1:2047],
        [Complex{Int16}(4096 - idx, idx       ) for idx in 1:2047]
    )
    sign_extend!(sig)
    for idx in 1:length(sig)
        @test real(sig[idx]) == -imag(sig[idx])
    end
    # Test our two extremal points that do not have duals as above:
    sig = [Complex{Int16}(0, 2048)]
    sign_extend!(sig)
    @test sig[1] == Complex{Int16}(0, -2048)
end
