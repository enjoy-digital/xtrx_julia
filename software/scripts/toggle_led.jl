using SoapySDR


for dev in Devices(driver="XTRX")
    println("serial:", dev["serial"])
    Device(dev) do d
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", 0xf0000000|0x4800, 1)
        println("press enter to continue")
        readline()
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", 0xf0000000|0x4800, 0)
    end
end