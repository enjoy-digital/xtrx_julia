using SoapySDR
using XTRX: CSRs

dev = Device(Devices(driver="XTRX", serial="134c5241b884854")[1])
#dev = Device(Devices(driver="XTRX")[2])

@info "Restarting GPS..."
dev[SoapySDR.Setting("GPS_ENABLE")] = "FALSE"

sleep(2)
@info "Enabling GPS..."
dev[SoapySDR.Setting("GPS_ENABLE")] = "TRUE"

# Enable PPS in/out
SoapySDR.SoapySDRDevice_writeRegister(dev.ptr, "LitePCI", CSRs.CSR_SYNCHRO_CONTROL_ADDR,
    (0b0001 << CSRs.CSR_SYNCHRO_CONTROL_INT_SOURCE_OFFSET) | (0b0001 << CSRs.CSR_SYNCHRO_CONTROL_OUT_SOURCE_OFFSET))

while true
    ret = unsafe_string(SoapySDR.SoapySDRDevice_readUART(dev, "GPS", 100000))
    isempty(ret) || print(ret)
end
