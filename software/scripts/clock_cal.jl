using SoapySDR
using Logging
using XTRX: CSRs

trials = 2

const latch_addr = CSRs.CSR_BASE | CSRs.CSR_VCTCXO_CYCLES_LATCH_ADDR
const cycles_addr = CSRs.CSR_BASE | CSRs.CSR_VCTCXO_CYCLES_ADDR

function get_cycles(d)
    SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", latch_addr, 1)
    before = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", cycles_addr)
    Base.Libc.systemsleep(1)
    SoapySDR.SoapySDRDevice_writeRegister(d, "LitePCI", latch_addr, 1)
    after = SoapySDR.SoapySDRDevice_readRegister(d, "LitePCI", cycles_addr)
    return after - before
end

for dev in Devices(driver="XTRX")
    println("Checking VCTCXO clock")
    try
        Device(dev) do d
            if "--dac" in ARGS
                for i in 0:15
                    dac_val = UInt16(i)*0x111
                    d[SoapySDR.Setting("DAC_SET")] = string(dac_val)
                    cycles = get_cycles(d)
                    println("VCTCXO clock:", cycles, " (DAC_SET=$(repr(dac_val))")
                end
            else
                for clksrc in d.clock_sources
                    d.clock_source = clksrc
                    for _ in 1:trials
                        cycles = get_cycles(d)
                        println("VCTCXO clock for $clksrc:", cycles)
                    end
                end
            end
        end
    catch e
        print(e)
        @warn "Device failed"
    end
end