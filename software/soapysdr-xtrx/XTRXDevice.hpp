//
// SoapySDR driver for the LMS7002M-based Fairwaves XTRX.
//
// Copyright (c) 2021 Julia Computing.
// Copyright (c) 2015-2015 Fairwaves, Inc.
// Copyright (c) 2015-2015 Rice University
// SPDX-License-Identifier: Apache-2.0
// http://www.apache.org/licenses/LICENSE-2.0
//

#include <SoapySDR/Device.hpp>
#include <SoapySDR/Logger.hpp>
#include <SoapySDR/Time.hpp>
#include <SoapySDR/Formats.hpp>
#include <mutex>
#include <cstring>
#include <cstdlib>
#include <stdexcept>
#include <iostream>

#include <LMS7002M/LMS7002M.h>
#include "liblitepcie.h"

#define DLL_EXPORT __attribute__ ((visibility ("default")))
#define BYTES_PER_SAMPLE 2 // TODO validate this

enum class TargetDevice { CPU, GPU };

class DLL_EXPORT SoapyXTRX : public SoapySDR::Device {
  public:
    SoapyXTRX(const SoapySDR::Kwargs &args);
    ~SoapyXTRX(void);

    // Identification API
    std::string getDriverKey(void) const { return "XTRX over LitePCIe"; }
    std::string getHardwareKey(void) const { return "Fairwaves XTRX"; }
    SoapySDR::Kwargs getHardwareInfo(void) const;


    // Channels API
    size_t getNumChannels(const int) const { return 2; }
    bool getFullDuplex(const int, const size_t) const { return true; }

    std::string getNativeStreamFormat(const int /*direction*/,
                                      const size_t /*channel*/,
                                      double &fullScale) const {
        fullScale = 4096;
        return SOAPY_SDR_CS16;
    }

    // Stream API
    SoapySDR::Stream *setupStream(const int direction,
                                  const std::string &format,
                                  const std::vector<size_t> &channels,
                                  const SoapySDR::Kwargs &args);
    void closeStream(SoapySDR::Stream *stream) override;
    int activateStream(SoapySDR::Stream *stream, const int flags,
                       const long long timeNs, const size_t numElems) override;
    int deactivateStream(SoapySDR::Stream *stream, const int flags,
                         const long long timeNs) override;
    size_t getStreamMTU(SoapySDR::Stream *stream) const override;
    size_t getNumDirectAccessBuffers(SoapySDR::Stream *stream) override;
    int getDirectAccessBufferAddrs(SoapySDR::Stream *stream,
                                   const size_t handle, void **buffs) override;
    int acquireReadBuffer(SoapySDR::Stream *stream, size_t &handl,
                          const void **buffs, int &flags, long long &timeNs,
                          const long timeoutUs) override;
    void releaseReadBuffer(SoapySDR::Stream *stream, size_t handle) override;
    int acquireWriteBuffer(SoapySDR::Stream *stream, size_t &handle,
                           void **buffs, const long timeoutUs) override;
    void releaseWriteBuffer(SoapySDR::Stream *stream, size_t handle,
                            const size_t numElems, int &flags,
                            const long long timeNs = 0) override;

    std::vector<std::string> getStreamFormats(const int direction, const size_t channel) const;


    // Antenna API
    std::vector<std::string> listAntennas(const int direction,
                                          const size_t channel) const override;
    void setAntenna(const int direction, const size_t channel,
                    const std::string &name) override;
    std::string getAntenna(const int direction,
                           const size_t channel) const override;

    std::map<int, std::map<size_t, std::string>> _cachedAntValues;

    // Frontend corrections API
    bool hasDCOffsetMode(const int direction,
                         const size_t channel) const override;
    void setDCOffsetMode(const int direction, const size_t channel,
                         const bool automatic) override;
    bool getDCOffsetMode(const int direction,
                         const size_t channel) const override;
    bool hasDCOffset(const int direction,
                     const size_t channel) const override;
    void setDCOffset(const int direction, const size_t channel,
                     const std::complex<double> &offset) override;
    std::complex<double> getDCOffset(const int direction,
                                     const size_t channel) const override;
    bool hasIQBalance(const int /*direction*/, const size_t /*channel*/) const {
        return true;
    }
    void setIQBalance(const int direction, const size_t channel,
                      const std::complex<double> &balance) override;
    std::complex<double> getIQBalance(const int direction,
                                      const size_t channel) const override;

    bool _rxDCOffsetMode;
    std::complex<double> _txDCOffset;
    std::map<int, std::map<size_t, std::complex<double>>> _cachedIqBalValues;

    // Gain API
    std::vector<std::string> listGains(const int direction,
                                       const size_t channel) const override;
    void setGain(const int direction, const size_t channel,
                 const std::string &name, const double value) override;
    double getGain(const int direction, const size_t channel,
                   const std::string &name) const override;
    SoapySDR::Range getGainRange(const int direction, const size_t channel,
                                 const std::string &name) const override;

    std::map<int, std::map<size_t, std::map<std::string, double>>>
        _cachedGainValues;

    // Frequency API
    void
    setFrequency(const int direction, const size_t channel, const std::string &,
                 const double frequency,
                 const SoapySDR::Kwargs &args = SoapySDR::Kwargs()) override;
    double getFrequency(const int direction, const size_t channel,
                        const std::string &name) const override;
    std::vector<std::string> listFrequencies(const int,
                                             const size_t) const override;
    SoapySDR::RangeList getFrequencyRange(const int, const size_t,
                                          const std::string &) const override;

    std::map<int, std::map<size_t, std::map<std::string, double>>>
        _cachedFreqValues;

    // Sample Rate API
    void setSampleRate(const int direction, const size_t,
                       const double rate) override;
    double getSampleRate(const int direction, const size_t) const override;
    std::vector<double> listSampleRates(const int direction,
                                        const size_t) const override;

    std::map<int, double> _cachedSampleRates;

    // BW filter API
    void setBandwidth(const int direction, const size_t channel,
                      const double bw) override;
    double getBandwidth(const int direction,
                        const size_t channel) const override;
    std::vector<double> listBandwidths(const int direction,
                                       const size_t channel) const override;

    std::map<int, std::map<size_t, double>> _cachedFilterBws;

    // Clocking API
    double getTSPRate(const int direction) const;
    void setMasterClockRate(const double rate) override;
    double getMasterClockRate(void) const override;
    void setReferenceClockRate(const double rate) override;
    double getReferenceClockRate(void) const override;
    SoapySDR::RangeList getReferenceClockRates(void) const override;
    std::vector<std::string> listClockSources(void) const override;
    void setClockSource(const std::string &source) override;
    std::string getClockSource(void) const override;

    // Sensor API
    std::vector<std::string> listSensors(void) const override;
    SoapySDR::ArgInfo getSensorInfo(const std::string &key) const override;
    std::string readSensor(const std::string &key) const override;

    // Register API
    std::vector<std::string> listRegisterInterfaces(void) const override;
    void writeRegister(const unsigned addr, const unsigned value) override;
    unsigned readRegister(const unsigned addr) const override;
    void writeRegister(const std::string &name, const unsigned addr, const unsigned value) override;
    unsigned readRegister(const std::string &name, const unsigned addr) const override;

    // Settings API
    //
    // Supported settings;
    //
    //  - RXTSP_ENABLE(TRUE/FALSE) - call the RX TSP enable routine.
    //    Call with TRUE (enable) to reapply default settings.
    //
    //  - TXTSP_ENABLE(TRUE/FALSE) - call the TX TSP enable routine.
    //    Call with TRUE (enable) to reapply default settings.
    //
    //  - RBB_ENABLE(TRUE/FALSE) - call the RX baseband enable routine.
    //    Call with TRUE (enable) to reapply default settings.
    //
    //  - TBB_ENABLE(TRUE/FALSE) - call the TX baseband enable routine.
    //    Call with TRUE (enable) to reapply default settings.
    //
    //  - RXTSP_TSG_CONST(amplitude) - set the RX digital signal generator
    //    for a constant valued output.
    //
    //  - TXTSP_TSG_CONST(amplitude) - set the TX digital signal generator
    //    for a constant valued output.
    //
    //  - TBB_ENABLE_LOOPBACK(path) - enable TX baseband loopback.
    //    Use LB_DISCONNECTED, LB_DAC_CURRENT, LB_LB_LADDER, or LB_MAIN_TBB for
    //    the path.
    //
    //  - TBB_SET_PATH(path) set the TX baseband input path.
    //    Use TBB_BYP, TBB_S5, TBB_LAD, TBB_LBF, TBB_HBF for bypassing or filter path.
    //
    //  - RBB_SET_PATH(path) set the RX baseband input path.
    //    Use BYP, LBF, HBF for bypassing or filter path.
    //    Use LB_BYP, LB_LBF, LB_HBF for loopback versions.
    //
    //  - LOOPBACK_ENABLE(TRUE/FALSE)
    //    Enable the LMS7002M's digital loopback
    //
    //  - LOOPBACK_ENABLE_LFSR(TRUE/FALSE)
    //    Enable the LMS7002M's LFSR loopback
    //
    //  - RESET_RX_FIFO(TRUE/FALSE)
    //    Reset all logic registers and FIFO state.
    //
    //  - FPGA_TX_RX_LOOPBACK_ENABLE(TRUE/FALSE)
    //    Enable a TX/RX loopback within the FPGA (before the LMS7002M PHY).
    //
    //  - FPGA_DMA_LOOPBACK_ENABLE(TRUE/FALSE)
    //    Enable the DMA loopback within the FPGA (connecting DMA reader to writer)
    //
    //  - FPGA_TX_PATTERN(pattern) - set the pattern for the TX pattern generator.
    //    pattern 0: disable pattern generator
    //    pattern 1: counter
    //    This pattern generator can be used with both the FPGA's and the
    //    LMS7002M's loopback to validate the digital chain.
    //
    //  - FPGA_RX_PATTERN(pattern) - set the pattern for the TX pattern checker.
    //    pattern 0: disable pattern generator
    //    pattern 1: counter
    //    This can be useful to validate the LMS7002M PHY and determine delays
    //    without involving the DMA. With the LMS7002M's loopback enabled, that
    //    means TX generator -> PHY -> LMS7002M -> PHY -> RX checker.
    //
    //  - FPGX_RX_PATTERN_ERRORS() - return the errors detected by the pattern
    //    generator. This can be used to calibrate the RX/TX delays.
    //
    //  - FPGA_TX_DELAY(delay) - get or set the TX clock delay between the FPGA and RF IC.
    //
    //  - FPGA_RX_DELAY(delay) - get or set the RX clock delay between the FPGA and RF IC.
    //
    //  - DUMP_INI(path) - dump the LMS7002M's registers to an INI file.
    //
    //  - RXTSP_TONE(div) - enable a test tone signal for the RX TSP chain with
    //    a given clock divider. Reset this by re-enabling RXTSP_ENABLE.
    //
    //  - TXTSP_TONE(div) - enable a test tone signal for the TX TSP chain with
    //    a given clock divider. Reset this by re-enabling TXTSP_ENABLE.
    //
    //  - RXTSP_ENABLE(TRUE/FALSE) - initialize the RX TSP chain
    //
    //  - TXTSP_ENABLE(TRUE/FALSE) - initialize the TX TSP chain
    std::string readSetting(const std::string &key) const;
    void writeSetting(const std::string &key,
                      const std::string &value) override;

    int readStream(
        SoapySDR::Stream *stream,
        void * const *buffs,
        const size_t numElems,
        int &flags,
        long long &timeNs,
        const long timeoutUs = 100000 );


    int writeStream(
            SoapySDR::Stream *stream,
            const void * const *buffs,
            const size_t numElems,
            int &flags,
            const long long timeNs = 0,
            const long timeoutUs = 100000);

  private:
    SoapySDR::Stream *const TX_STREAM = (SoapySDR::Stream *)0x1;
    SoapySDR::Stream *const RX_STREAM = (SoapySDR::Stream *)0x2;

    struct litepcie_ioctl_mmap_dma_info _dma_mmap_info;
    TargetDevice _dma_target;
    void *_dma_buf;

    struct Stream {
        Stream() : opened(false), remainderHandle(-1), remainderSamps(0),
                   remainderOffset(0), remainderBuff(nullptr) {}

        bool opened;
        void *buf;
        struct pollfd fds;
        int64_t hw_count, sw_count, user_count;

        int32_t remainderHandle;
        size_t remainderSamps;
        size_t remainderOffset;
        int8_t* remainderBuff;
        std::string format;
        std::vector<size_t> channels;
    };

    struct RXStream: Stream {
        uint32_t vga_gain;
        uint32_t lna_gain;
        uint8_t amp_gain;
        double samplerate;
        uint32_t bandwidth;
        uint64_t frequency;

        bool overflow;
    };

    struct TXStream: Stream {
        uint32_t vga_gain;
        uint8_t amp_gain;
        double samplerate;
        uint32_t bandwidth;
        uint64_t frequency;
        bool bias;

        bool underflow;

        bool burst_end;
        int32_t burst_samps;
    } ;

    RXStream _rx_stream;
    TXStream _tx_stream;

    LMS7002M_dir_t dir2LMS(const int direction) const {
        return (direction == SOAPY_SDR_RX) ? LMS_RX : LMS_TX;
    }

    LMS7002M_chan_t ch2LMS(const size_t channel) const {
        return (channel == 0) ? LMS_CHA : LMS_CHB;
    }

    const char *dir2Str(const int direction) const {
        return (direction == SOAPY_SDR_RX) ? "RX" : "TX";
    }

    int _fd;
    LMS7002M_t *_lms;
    double _masterClockRate;
    double _refClockRate;

    // calibration data
    std::vector<std::map<std::string, std::string>> _calData;

    // register protection
    std::mutex _mutex;
};
