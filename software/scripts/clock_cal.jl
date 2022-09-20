using SoapySDR
using Logging
using XTRX

trials = 2

latch_addr = XTRX.CSR_BASE | XTRX.CSR_VCTCXO_CYCLES_LATCH_ADDR
cycles_addr = XTRX.CSR_BASE | XTRX.CSR_VCTCXO_CYCLES_ADDR

for dev in Devices(driver="XTRX")
    println("Checking VCTCXO clock")
    Device(dev) do d
        for clksrc in d.clock_sources
            d.clock_source = clksrc
            for _ in 1:trials
                SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", latch_addr, 1)
                before = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", cycles_addr)
                sleep(1)
                SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", latch_addr, 1)
                after = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", cycles_addr)
                println("VCTCXO clock:", after-before)
            end
        end
    end
end