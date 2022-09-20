using SoapySDR
using XTRX

led_addr = XTRX.CSR_BASE | XTRX.CSR_LEDS_OUT_ADDR

for dev in Devices(driver="XTRX")
    Device(dev) do d
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", led_addr, 0)
    end
end

for dev in Devices(driver="XTRX")
    Device(dev) do d
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", led_addr, 1)
        println("serial:", dev["serial"])
        println("press enter to continue")
        readline()
        SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", led_addr, 0)
    end
end