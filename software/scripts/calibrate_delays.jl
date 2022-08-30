# test script to calibrate tx/rx delays

using SoapySDR, Unitful, Printf

function main()
    devs = Devices(parse(KWArgs, "driver=XTRX"))
    Device(first(devs)) do dev
        # Setup transmission/recieve parameters
        frequency = 1575.00u"MHz"
        sample_rate = 6u"MHz"
        for (c_idx, cr) in enumerate(dev.rx)
            cr.bandwidth = sample_rate
            cr.frequency = frequency
            cr.sample_rate = sample_rate
        end
        for ct in dev.tx
            ct.bandwidth = sample_rate
            ct.frequency = frequency
            ct.sample_rate = sample_rate
            ct.gain = 30u"dB"
        end

        SoapySDR.SoapySDRDevice_writeSetting(dev, "LOOPBACK_ENABLE", "TRUE")

        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_PATTERN", "1")
        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_RX_PATTERN", "1")

        print("TX / RX ")
        for rx in 0:31
            @printf("%02d ", rx)
        end
        println()
        for tx in 0:31
            SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_DELAY", string(tx))
            @printf("%02d |    ", tx)
            for rx in 0:31
                SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_RX_DELAY", string(rx))

                e0 = unsafe_string(SoapySDR.SoapySDRDevice_readSetting(dev, "FPGA_RX_PATTERN_ERRORS"))
                sleep(0.01)
                e1 = unsafe_string(SoapySDR.SoapySDRDevice_readSetting(dev, "FPGA_RX_PATTERN_ERRORS"))
                errors = parse(Int, e1) - parse(Int, e0)
                if errors != 0
                    print(" - ")
                else
                    print(" X ")
                end
            end
            println()
        end

        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_TX_PATTERN", "0")
        SoapySDR.SoapySDRDevice_writeSetting(dev, "FPGA_RX_PATTERN", "0")
    end
end

isinteractive() || main()
