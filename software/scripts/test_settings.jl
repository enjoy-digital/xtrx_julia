if !haskey(ENV, "SOAPY_SDR_PLUGIN_PATH") || isempty(ENV["SOAPY_SDR_PLUGIN_PATH"])
    ENV["SOAPY_SDR_PLUGIN_PATH"] = joinpath(@__DIR__, "../soapysdr/build")
end

@show ENV["SOAPY_SDR_PLUGIN_PATH"]

using SoapySDR
using Test

SoapySDR.register_log_handler()

devs = Devices()

@test !isempty(devs)

dev = open(devs[1])

@info "Checking Sensor Readouts..."

for sensor in dev.sensors
    @info "Sensor Readout:  $(sensor.name) : $(dev[sensor])"
end

@testset "Channels" begin
for dir in (dev.rx, dev.tx)
    for i in eachindex(dir)
        txrx = dir[i]
        @testset "Channel: $txrx" begin
            @info "Testing Sample Rate Settings..."
            for rate in SoapySDR.sample_rate_ranges(txrx)
                txrx.sample_rate = first(rate)
                @test txrx.sample_rate == first(rate)
                txrx.sample_rate = last(rate)
                @test txrx.sample_rate == last(rate)
            end
            @info "Testing Bandwidth Settings..."
            for rate in SoapySDR.bandwidth_ranges(txrx)
                txrx.bandwidth = first(rate)
                @test txrx.bandwidth == first(rate)
                txrx.bandwidth = last(rate)
                @test txrx.bandwidth == last(rate)
            end
            @info "Testing Frequency Settings..."
            for rate in SoapySDR.frequency_ranges(txrx)
                txrx.frequency = first(rate)
                @test txrx.frequency == first(rate)
                txrx.frequency = last(rate)
                @test txrx.frequency == last(rate)
            end
        end
    end
end
end
