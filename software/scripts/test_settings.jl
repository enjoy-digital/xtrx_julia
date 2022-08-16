if !haskey(ENV, "SOAPY_SDR_PLUGIN_PATH") || isempty(ENV["SOAPY_SDR_PLUGIN_PATH"])
    ENV["SOAPY_SDR_PLUGIN_PATH"] = "/home/sjkelly/xtrx_julia/build/soapysdr/lib/SoapySDR/modules0.8"
    #ENV["SOAPY_SDR_PLUGIN_PATH"] = joinpath(@__DIR__, "../soapysdr-xtrx/build")
end

@show ENV["SOAPY_SDR_PLUGIN_PATH"]

using SoapySDR
using Test
using Unitful

SoapySDR.register_log_handler()

devs = Devices()

@test !isempty(devs)

dev = Device(devs[1])

@info "Checking Sensor Readouts..."

for sensor in dev.sensors
    @info "Sensor Readout:  $(sensor.name) : $(dev[sensor])"
end

@info "Clock Settings..."
@testset "Clock Settings" begin
    
end

@testset "Channels" begin
for dir in (dev.rx, dev.tx)
    for i in eachindex(dir)
        txrx = dir[i]
        @testset "Channel: $i Dir: $(txrx.direction)" begin
            @testset "Antenna Settings" begin
            for antenna in txrx.antennas
                txrx.antenna = antenna
                @test txrx.antenna == antenna
            end
            end
            @testset "Sample Rate Settings" begin
            for rate in SoapySDR.sample_rate_ranges(txrx)
                txrx.sample_rate = first(rate)
                @test txrx.sample_rate == first(rate)
                txrx.sample_rate = last(rate)
                @test txrx.sample_rate == last(rate)
            end
            end
            @testset "Bandwidth Settings" begin
            for rate in SoapySDR.bandwidth_ranges(txrx)
                in(txrx, dev.tx) && first(rate) >= 2.4u"MHz" && break
                txrx.bandwidth = first(rate)
                @test txrx.bandwidth == first(rate)
                txrx.bandwidth = last(rate)
                @test txrx.bandwidth == last(rate)
            end
            end
            @testset "Frequency Settings" begin
            for rate in SoapySDR.frequency_ranges(txrx)
                first(rate) < 0u"Hz" && continue 
                txrx.frequency = first(rate)
                @test txrx.frequency == first(rate)
                txrx.frequency = last(rate)
                @test txrx.frequency == last(rate)
            end
            end
            @testset "Gain Settings" begin
            for gainelt in txrx.gain_elements
                rng = SoapySDR.gainrange(txrx, gainelt)
                txrx[gainelt] = first(rng)
                @test txrx[gainelt] == first(rng)
                txrx[gainelt] = last(rng)
                @test txrx[gainelt] == last(rng)
            end
            end
        end
    end
end
end

finalize(dev)