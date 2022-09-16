using SoapySDR
using Logging

SoapySDR.register_log_handler()

trials = 10

#for dev in Devices(driver="XTRX")
dev = Devices(driver="XTRX")[1]
    println("Checking VCTCXO clock")
    Device(dev) do d
        for _ in 1:trials
            SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", 0xf0000000|0xc004, 1)
            before = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", 0xf0000000|0xc008)
            sleep(1)
            SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", 0xf0000000|0xc004, 1)
            after = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", 0xf0000000|0xc008)
            println("VCTCXO clock:", after-before)
        end
    end
#end