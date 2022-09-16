using SoapySDR


for dev in Devices(driver="XTRX")
    Device(dev) do d
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", 0xf0000000|0x4800, 0)
    end
end

for dev in Devices(driver="XTRX")
    Device(dev) do d
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", 0xf0000000|0x4800, 1)
        println("serial:", dev["serial"])
        println("press enter to continue")
        readline()
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", 0xf0000000|0x4800, 0)
    end
end