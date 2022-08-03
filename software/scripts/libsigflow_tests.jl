using Test
include("libsigflow.jl")

function verify_test_pattern_buffer(buff, idx, buff_size)
    @test length(buff) == buff_size
    @test real(buff[1]) == imag(buff[1])
    @test real(buff[end]) == buff_size*idx
    @test real(buff[1]) == buff_size*(idx-1) + 1
end

@testset "generate_test_pattern" begin
    num_samples = 32
    buff_size = 4
    c = generate_test_pattern(num_samples; buff_size)
    for idx in 1:div(num_samples, buff_size)
        buff = take!(c)
        verify_test_pattern_buffer(buff, idx, buff_size)
    end
    sleep(0.001)
    @test !isopen(c)
end

@testset "tee" begin
    num_samples = 32
    buff_size = 4
    c1, c2 = tee(generate_test_pattern(num_samples; buff_size))
    for idx in 1:div(num_samples,buff_size)
        for c in (c1, c2)
            buff = take!(c)
            verify_test_pattern_buffer(buff, idx, buff_size)
        end
    end
    sleep(0.001)
    @test !isopen(c1)
    @test !isopen(c2)
end

@testset "rechunk" begin
    # First, test rechunking to twice the size
    @testset "x -> 2x" begin
        num_samples = 32
        buff_size = 4
        c_small, c_large = tee(generate_test_pattern(num_samples; buff_size))
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

    # Next, test rechunking to half the size
    @testset "2x -> x" begin
        num_samples = 32
        buff_size = 4
        c_small, c_large = tee(generate_test_pattern(num_samples; buff_size))
        c_small = rechunk(c_small, div(buff_size,2))
        for idx in 1:div(num_samples, buff_size)
            buff_small_0 = take!(c_small)
            buff_small_1 = take!(c_small)
            buff_large = take!(c_large)

            @test vcat(buff_small_0, buff_small_1) == buff_large
        end
        sleep(0.001)
        @test !isopen(c_small)
        @test !isopen(c_large)
    end

    # Next, test rechunking to an odd, non-overlapping size:
    @testset "x -> y" begin
        num_samples = 10240
        buff_size = 8
        new_buff_size = 7
        c = rechunk(generate_test_pattern(num_samples; buff_size), new_buff_size)
        buff_size = new_buff_size
        for idx in 1:div(num_samples, new_buff_size)
            buff = take!(c)
            verify_test_pattern_buffer(buff, idx, buff_size)
        end
        sleep(0.001)
        @test !isopen(c)
    end

    @testset "8160 -> 400" begin
        buff_size = 8160
        num_samples = buff_size*100
        new_buff_size = 400
        c = rechunk(generate_test_pattern(num_samples; buff_size), new_buff_size)
        for idx in 1:div(num_samples, new_buff_size)
            buff = take!(c)
            verify_test_pattern_buffer(buff, idx, new_buff_size)
        end
        sleep(0.001)
        @test !isopen(c)
    end
end

@testset "log_stream_xfer" begin
    num_samples = 24
    buff_size = 8
    c = generate_test_pattern(num_samples; buff_size)

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

