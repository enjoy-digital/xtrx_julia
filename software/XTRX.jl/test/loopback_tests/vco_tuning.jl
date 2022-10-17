module VCOTuning

# Force very verbose driver
ENV["SOAPY_SDR_LOG_LEVEL"]="DEBUG"

using XTRX, Unitful, Test

function vco_tune_test(;samplerate = 10u"MHz", frequency=1u"GHz")
    config = XTRXTestConfig(;
        rx_params = XTRX.default_rx_parameters(;samplerate, frequency),
        tx_params = XTRX.default_tx_parameters(;samplerate, frequency),
    )

    XTRX.run_test(config) do dev, s_tx, s_rx
    end
    return test_passes
end

function run_tests()
    @testset "VCO Tuning" begin
        for frequency in (
                # A few very low frequencies
                30u"MHz", 50u"MHz", 75u"MHz",
                # Sweep by 100MHz up through to the highest frequency
                (100u"MHz" * idx for idx in 1:30)...,
            ), samplerate in (
                # Start with some low samplerates
                1u"MHz", 2u"MHz", 4u"MHz", 5u"MHz",
                # Try and push it to the high end too
                10u"MHz", 20u"MHz", 40u"MHz"
            )
            # Run the test, assert that we can get a good VCO lock
            @test vco_tune_test(;frequency, samplerate)
        end
    end
end

end # module
