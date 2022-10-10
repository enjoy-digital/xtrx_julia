using SoapySDR
using Logging
using XTRX: CSRs

trials = 2

latch_addr = CSRs.CSR_BASE | CSRs.CSR_VCTCXO_CYCLES_LATCH_ADDR
cycles_addr = CSRs.CSR_BASE | CSRs.CSR_VCTCXO_CYCLES_ADDR

for dev in Devices(driver="XTRX")
    println("Checking VCTCXO clock")
    try
        Device(dev) do d
            for clksrc in d.clock_sources
                d.clock_source = clksrc
                for _ in 1:trials
                    SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", latch_addr, 1)
                    before = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", cycles_addr)
                    Base.Libc.systemsleep(1)
                    SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", latch_addr, 1)
                    after = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", cycles_addr)
                    println("VCTCXO clock for $clksrc:", after-before)
                end
            end
        end
    catch e
        @warn "Device failed"
    end
end