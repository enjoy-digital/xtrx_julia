//
// SoapySDR driver for the LMS7002M-based Fairwaves XTRX.
//
// Copyright (c) 2021 Julia Computing.
// Copyright (c) 2015-2015 Fairwaves, Inc.
// Copyright (c) 2015-2015 Rice University
// SPDX-License-Identifier: Apache-2.0
// http://www.apache.org/licenses/LICENSE-2.0
//

// TODO
//
// - we're not properly setting the channels here, see ch2LMS/setAntenna/etc
//   in the EVB7 driver (https://github.com/myriadrf/LMS7002M-driver/tree/master/evb7)
//
// - we're also completely ignoring formats
//
// - implement the user-friendlier non-zero copy API on top of this? see e.g.
//   https://github.com/pothosware/SoapyHackRF/blob/master/HackRF_Streaming.cpp

#include "XTRXDevice.hpp"

#include <chrono>
#include <cassert>
#include <thread>
#include <sys/mman.h>

SoapySDR::Stream *SoapyXTRX::setupStream(const int direction,
                                         const std::string &format,
                                         const std::vector<size_t> &/*channels*/,
                                         const SoapySDR::Kwargs &/*args*/) {
    std::lock_guard<std::mutex> lock(_mutex);

    if (direction == SOAPY_SDR_RX) {
        if (_rx_stream.opened)
            throw std::runtime_error("RX stream already opened");

        // configure the file descriptor watcher
        _rx_stream.fds.fd = _fd;
        _rx_stream.fds.events = POLLIN;

        // initialize the DMA engine
        if ((litepcie_request_dma(_fd, 0, 1) == 0))
            throw std::runtime_error("DMA not available");

        // mmap the DMA buffers
        _rx_stream.buf = mmap(NULL,
                              _dma_mmap_info.dma_rx_buf_count *
                                  _dma_mmap_info.dma_rx_buf_size,
                              PROT_READ | PROT_WRITE, MAP_SHARED, _fd,
                              _dma_mmap_info.dma_rx_buf_offset);
        if (_rx_stream.buf == MAP_FAILED)
            throw std::runtime_error("MMAP failed");

        // make sure the DMA is disabled, or counters could be in a bad state
        litepcie_dma_writer(_fd, 0, &_rx_stream.hw_count, &_rx_stream.sw_count);

        _rx_stream.opened = true;

        _rx_stream.format = format;

        return RX_STREAM;
    } else if (direction == SOAPY_SDR_TX) {
        if (_tx_stream.opened)
            throw std::runtime_error("TX stream already opened");

        // configure the file descriptor watcher
        _tx_stream.fds.fd = _fd;
        _tx_stream.fds.events = POLLOUT;

        // initialize the DMA engine
        if ((litepcie_request_dma(_fd, 1, 0) == 0))
            throw std::runtime_error("DMA not available");

        // mmap the DMA buffers
        _tx_stream.buf = mmap(
            NULL,
            _dma_mmap_info.dma_tx_buf_count * _dma_mmap_info.dma_tx_buf_size,
            PROT_WRITE, MAP_SHARED, _fd, _dma_mmap_info.dma_tx_buf_offset);
        if (_tx_stream.buf == MAP_FAILED)
            throw std::runtime_error("MMAP failed");

        // make sure the DMA is disabled, or counters could be in a bad state
        litepcie_dma_reader(_fd, 0, &_tx_stream.hw_count, &_tx_stream.sw_count);

        _tx_stream.opened = true;

        _tx_stream.format = format;

        return TX_STREAM;
    } else {
        throw std::runtime_error("Invalid direction");
    }
}

void SoapyXTRX::closeStream(SoapySDR::Stream *stream) {
    std::lock_guard<std::mutex> lock(_mutex);

    if (stream == RX_STREAM) {
        // release the DMA engine
        litepcie_release_dma(_fd, 0, 1);

        munmap(_rx_stream.buf, _dma_mmap_info.dma_rx_buf_size *
                                   _dma_mmap_info.dma_rx_buf_count);
        _rx_stream.opened = false;
    } else if (stream == TX_STREAM) {
        // release the DMA engine
        litepcie_release_dma(_fd, 1, 0);

        munmap(_tx_stream.buf, _dma_mmap_info.dma_tx_buf_size *
                                   _dma_mmap_info.dma_tx_buf_count);
        _tx_stream.opened = false;
    }
}

int SoapyXTRX::activateStream(SoapySDR::Stream *stream, const int /*flags*/,
                              const long long /*timeNs*/,
                              const size_t /*numElems*/) {
    if (stream == RX_STREAM) {
        // enable the DMA engine
        litepcie_dma_writer(_fd, 1, &_rx_stream.hw_count, &_rx_stream.sw_count);
        _rx_stream.user_count = 0;
    } else if (stream == TX_STREAM) {
        // enable the DMA engine
        litepcie_dma_reader(_fd, 1, &_tx_stream.hw_count, &_tx_stream.sw_count);
        _tx_stream.user_count = 0;
    }

    // TODO: set-up the LMS7002M

    return 0;
}

int SoapyXTRX::deactivateStream(SoapySDR::Stream *stream, const int /*flags*/,
                                const long long /*timeNs*/) {
    if (stream == RX_STREAM) {
        // disable the DMA engine
        litepcie_dma_writer(_fd, 0, &_rx_stream.hw_count, &_rx_stream.sw_count);
    } else if (stream == TX_STREAM) {
        // disable the DMA engine
        litepcie_dma_reader(_fd, 1, &_tx_stream.hw_count, &_tx_stream.sw_count);
    }
    return 0;
}


/*******************************************************************
 * Direct buffer API
 ******************************************************************/

size_t SoapyXTRX::getStreamMTU(SoapySDR::Stream *stream) const {
    if (stream == RX_STREAM)
        // each sample is 2 * Complex{Int16}
        return _dma_mmap_info.dma_rx_buf_size/(2*2*sizeof(int16_t));
    else if (stream == TX_STREAM)
        return _dma_mmap_info.dma_tx_buf_size/(2*2*sizeof(int16_t));
    else
        throw std::runtime_error("SoapySDR::getStreamMTU(): invalid stream");
}

size_t SoapyXTRX::getNumDirectAccessBuffers(SoapySDR::Stream *stream) {
    if (stream == RX_STREAM)
        return _dma_mmap_info.dma_rx_buf_count;
    else if (stream == TX_STREAM)
        return _dma_mmap_info.dma_tx_buf_count;
    else
        throw std::runtime_error("SoapySDR::getNumDirectAccessBuffers(): invalid stream");
}

int SoapyXTRX::getDirectAccessBufferAddrs(SoapySDR::Stream *stream,
                                          const size_t handle, void **buffs) {
    if (_dma_target == TargetDevice::CPU && stream == RX_STREAM)
        buffs[0] =
            (char *)_rx_stream.buf + handle * _dma_mmap_info.dma_rx_buf_size;
    else if (_dma_target == TargetDevice::CPU && stream == TX_STREAM)
        buffs[0] =
            (char *)_tx_stream.buf + handle * _dma_mmap_info.dma_tx_buf_size;
    // XXX: this is a leaky abstraction, exposing how the LitePCIe kernel driver
    //      manages its DMA buffers. normally this is hidden behind mmap,
    //      but we can't use its virtual addresses on the GPU.
    //
    //      alternatively, if we could re-map the mmap buffers into GPU address
    //      space, we could keep everything as it is, but cuMemHostRegister
    //      fails with INVALID_VALUE on such inputs (presumably because the
    //      underlying pages are already pointing to physical GPU memory).
    else if (_dma_target == TargetDevice::GPU &&
             (stream == RX_STREAM || stream == TX_STREAM))
        buffs[0] = (char *)_dma_buf +
                   // Index by (tx, rx) buffer tuples
                   handle * (_dma_mmap_info.dma_tx_buf_size +
                             _dma_mmap_info.dma_rx_buf_size) +
                   // Index past the tx buffer tuple element, if we want the `rx` buffer
                   (stream == RX_STREAM ? _dma_mmap_info.dma_tx_buf_size : 0);
    else
        throw std::runtime_error(
            "SoapySDR::getDirectAccessBufferAddrs(): invalid stream");
    return 0;
}

// Our DMA readers/writers are zero-copy (i.e. using a single buffer shared with
// the kernel), and use three counters to index that buffer:
// - hw_count: where the hardware has read from / written to
// - sw_count: where userspace has read from / written to
// - user_count: where userspace is currently reading from / writing to
//
// The distinction between sw and user makes it possible to keep track of which
// buffers are being processed. This is not supported by the LitePCIe DMA
// library, and is why we do it ourselves.
//
// In addition, with a separate user count, the implementation of read/write can
// advance buffers without performing a syscall (only having to interface with
// the kernel when retiring buffers). That however results in slower detection
// of overflows/underflows, so we make that configurable:
#define DETECT_EVERY_OVERFLOW  true
#define DETECT_EVERY_UNDERFLOW true

int SoapyXTRX::acquireReadBuffer(SoapySDR::Stream *stream, size_t &handle,
                                 const void **buffs, int &flags,
                                 long long &/*timeNs*/, const long timeoutUs) {
    if (stream != RX_STREAM)
        return SOAPY_SDR_STREAM_ERROR;

    // check if there are buffers available
    int buffers_available = _rx_stream.hw_count - _rx_stream.user_count;
    assert(buffers_available >= 0);

    // if not, check with the DMA engine
    if (buffers_available == 0 || DETECT_EVERY_OVERFLOW) {
        litepcie_dma_writer(_fd, 1, &_rx_stream.hw_count, &_rx_stream.sw_count);
        buffers_available = _rx_stream.hw_count - _rx_stream.user_count;
    }

    // if not, wait for new buffers to arrive
    if (buffers_available == 0) {
        int ret = poll(&_rx_stream.fds, 1, timeoutUs / 1000);
        if (ret < 0)
            throw std::runtime_error(
                "SoapyXTRX::acquireReadBuffer(): poll failed, " +
                std::string(strerror(errno)));
        else if (ret == 0) {
            return SOAPY_SDR_TIMEOUT;
        }

        // get new DMA counters
        litepcie_dma_writer(_fd, 1, &_rx_stream.hw_count, &_rx_stream.sw_count);
        buffers_available = _rx_stream.hw_count - _rx_stream.user_count;
        assert(buffers_available > 0);
    }

    // detect overflows of the underlying circular buffer
    if ((_rx_stream.hw_count - _rx_stream.sw_count) >
        ((int64_t)_dma_mmap_info.dma_rx_buf_count / 2)) {
        // drain all buffers to get out of the overflow quicker
        struct litepcie_ioctl_mmap_dma_update mmap_dma_update;
        mmap_dma_update.sw_count = _rx_stream.hw_count;
        checked_ioctl(_fd, LITEPCIE_IOCTL_MMAP_DMA_WRITER_UPDATE, &mmap_dma_update);
        _rx_stream.user_count = _rx_stream.hw_count;
        _rx_stream.sw_count = _rx_stream.hw_count;
        handle = -1;

        flags |= SOAPY_SDR_END_ABRUPT;
        return SOAPY_SDR_OVERFLOW;
    } else {
        // get the buffer
        int buf_offset = _rx_stream.user_count % _dma_mmap_info.dma_rx_buf_count;
        getDirectAccessBufferAddrs(stream, buf_offset, (void **)buffs);

        // update the DMA counters
        handle = _rx_stream.user_count;
        _rx_stream.user_count++;

        return getStreamMTU(stream);
    }
}

void SoapyXTRX::releaseReadBuffer(SoapySDR::Stream */*stream*/, size_t handle) {
    assert(handle != (size_t)-1 && "Attempt to release an invalid buffer (e.g., from an overflow)");

    // update the DMA counters
    struct litepcie_ioctl_mmap_dma_update mmap_dma_update;
    mmap_dma_update.sw_count = handle + 1;
    checked_ioctl(_fd, LITEPCIE_IOCTL_MMAP_DMA_WRITER_UPDATE, &mmap_dma_update);
}

int SoapyXTRX::acquireWriteBuffer(SoapySDR::Stream *stream, size_t &handle,
                                  void **buffs, const long timeoutUs) {
    if (stream != TX_STREAM)
        return SOAPY_SDR_STREAM_ERROR;

    // check if there are buffers available
    int buffers_pending = _tx_stream.user_count - _tx_stream.hw_count;
    assert(buffers_pending <= (int)_dma_mmap_info.dma_tx_buf_count);

    // if not, check with the DMA engine
    if (buffers_pending == ((int64_t)_dma_mmap_info.dma_tx_buf_count) ||
        DETECT_EVERY_UNDERFLOW) {
        litepcie_dma_reader(_fd, 1, &_tx_stream.hw_count, &_tx_stream.sw_count);
        buffers_pending = _tx_stream.user_count - _tx_stream.hw_count;
    }

    // if not, wait for new buffers to become available
    if (buffers_pending == ((int64_t)_dma_mmap_info.dma_tx_buf_count)) {
        int ret = poll(&_tx_stream.fds, 1, timeoutUs / 1000);
        if (ret < 0)
            throw std::runtime_error(
                "SoapyXTRX::acquireWriteBuffer(): poll failed, " +
                std::string(strerror(errno)));
        else if (ret == 0)
            return SOAPY_SDR_TIMEOUT;

        // get new DMA counters
        litepcie_dma_reader(_fd, 1, &_tx_stream.hw_count, &_tx_stream.sw_count);
        buffers_pending = _tx_stream.user_count - _tx_stream.hw_count;
        assert(buffers_pending < ((int64_t)_dma_mmap_info.dma_tx_buf_count));
    }

    // get the buffer
    int buf_offset = _tx_stream.user_count % _dma_mmap_info.dma_tx_buf_count;
    getDirectAccessBufferAddrs(stream, buf_offset, buffs);

    // update the DMA counters
    handle = _tx_stream.user_count;
    _tx_stream.user_count++;

    // detect underflows
    if (buffers_pending < 0) {
        return SOAPY_SDR_UNDERFLOW;
    } else {
        return getStreamMTU(stream);
    }
}

void SoapyXTRX::releaseWriteBuffer(SoapySDR::Stream */*stream*/, size_t handle,
                                   const size_t /*numElems*/, int &/*flags*/,
                                   const long long /*timeNs*/) {
    // XXX: inspect user-provided numElems and flags, and act upon them?

    // update the DMA counters so that the engine can submit this buffer
    struct litepcie_ioctl_mmap_dma_update mmap_dma_update;
    mmap_dma_update.sw_count = handle + 1;
    checked_ioctl(_fd, LITEPCIE_IOCTL_MMAP_DMA_READER_UPDATE, &mmap_dma_update);
}

void readbuf(int8_t *src, void *dst, uint32_t len, std::string format, size_t offset)
{

    if (format == SOAPY_SDR_CS16)
    {

        int16_t *samples_cs16 = (int16_t *)dst + offset * BYTES_PER_SAMPLE;
        for (uint32_t i = offset; i < len; i+=2)
        {
            samples_cs16[i * BYTES_PER_SAMPLE] = (int16_t)(src[i * BYTES_PER_SAMPLE] << 8);
            samples_cs16[i * BYTES_PER_SAMPLE + 1] = (int16_t)(src[i * BYTES_PER_SAMPLE + 1] << 8);
        }
    }
    else
    {
        SoapySDR_logf(SOAPY_SDR_ERROR, "Unsupported read format: %s", format.c_str());
    }
}

void writebuf(const void *src, int8_t *dst, uint32_t len, std::string format, size_t offset)
{
    if (format == SOAPY_SDR_CS16)
    {
        int16_t *samples_cs16 = (int16_t *)src + offset * BYTES_PER_SAMPLE;
        for (uint32_t i = offset; i < len; i+=2)
        {
            dst[i * BYTES_PER_SAMPLE] = (int8_t)(samples_cs16[i * BYTES_PER_SAMPLE] >> 8);
            dst[i * BYTES_PER_SAMPLE + 1] = (int8_t)(samples_cs16[i * BYTES_PER_SAMPLE + 1] >> 8);
        }
    }
    else
    {
        SoapySDR_logf(SOAPY_SDR_ERROR, "Unsupported write format: %s", format.c_str());
    }
}

int SoapyXTRX::readStream(
    SoapySDR::Stream *stream,
    void *const *buffs,
    const size_t numElems,
    int &flags,
    long long &timeNs,
    const long timeoutUs)
{
    if (stream != RX_STREAM)
    {
        return SOAPY_SDR_NOT_SUPPORTED;
    }
    /* this is the user's buffer for channel 0 */
    size_t returnedElems = std::min(numElems, this->getStreamMTU(stream));

    size_t samp_avail = 0;

    if (_rx_stream.remainderHandle >= 0)
    {

        const size_t n = std::min(_rx_stream.remainderSamps, returnedElems);

        if (n < returnedElems)
        {
            samp_avail = n;
        }

        // Read out channel A
        readbuf(_rx_stream.remainderBuff + _rx_stream.remainderOffset * BYTES_PER_SAMPLE, buffs[0], n/2, _rx_stream.format, 0);
        // Read out channel B
        readbuf(_rx_stream.remainderBuff + _rx_stream.remainderOffset * BYTES_PER_SAMPLE, buffs[1], n/2, _rx_stream.format, 0);

        _rx_stream.remainderOffset += n;
        _rx_stream.remainderSamps -= n;

        if (_rx_stream.remainderSamps == 0)
        {

            this->releaseReadBuffer(stream, _rx_stream.remainderHandle);
            _rx_stream.remainderHandle = -1;
            _rx_stream.remainderOffset = 0;
        }

        if (n == returnedElems)
            return returnedElems;
    }

    size_t handle;
    int ret = this->acquireReadBuffer(stream, handle, (const void **)&_rx_stream.remainderBuff, flags, timeNs, timeoutUs);

    if (ret < 0)
    {
        if ((ret == SOAPY_SDR_TIMEOUT) && (samp_avail > 0))
        {
            return samp_avail;
        }
        return ret;
    }

    _rx_stream.remainderHandle = handle;
    _rx_stream.remainderSamps = ret;

    const size_t n = std::min((returnedElems - samp_avail), _rx_stream.remainderSamps);

    readbuf(_rx_stream.remainderBuff, buffs[0], n, _rx_stream.format, samp_avail);
    _rx_stream.remainderSamps -= n;
    _rx_stream.remainderOffset += n;

    if (_rx_stream.remainderSamps == 0)
    {
        this->releaseReadBuffer(stream, _rx_stream.remainderHandle);
        _rx_stream.remainderHandle = -1;
        _rx_stream.remainderOffset = 0;
    }

    return (returnedElems);
}

int SoapyXTRX::writeStream(
    SoapySDR::Stream *stream,
    const void *const *buffs,
    const size_t numElems,
    int &flags,
    const long long timeNs,
    const long timeoutUs)
{
    if (stream != TX_STREAM)
    {
        return SOAPY_SDR_NOT_SUPPORTED;
    }

    size_t returnedElems = std::min(numElems, this->getStreamMTU(stream));

    size_t samp_avail = 0;

    if (_tx_stream.remainderHandle >= 0)
    {

        const size_t n = std::min(_tx_stream.remainderSamps, returnedElems);

        if (n < returnedElems)
        {
            samp_avail = n;
        }

        // Write out channel A
        writebuf(buffs[0], _tx_stream.remainderBuff + _tx_stream.remainderOffset * BYTES_PER_SAMPLE, n/2, _tx_stream.format, 0);
        // Write out channel B
        writebuf(buffs[1], _tx_stream.remainderBuff + _tx_stream.remainderOffset * BYTES_PER_SAMPLE, n/2, _tx_stream.format, 1);

        _tx_stream.remainderSamps -= n;
        _tx_stream.remainderOffset += n;

        if (_tx_stream.remainderSamps == 0)
        {
            this->releaseWriteBuffer(stream, _tx_stream.remainderHandle, _tx_stream.remainderOffset, flags, timeNs);
            _tx_stream.remainderHandle = -1;
            _tx_stream.remainderOffset = 0;
        }

        if (n == returnedElems)
            return returnedElems;
    }

    size_t handle;

    int ret = this->acquireWriteBuffer(stream, handle, (void **)&_tx_stream.remainderBuff, timeoutUs);
    if (ret < 0)
    {
        if ((ret == SOAPY_SDR_TIMEOUT) && (samp_avail > 0))
        {
            return samp_avail;
        }
        return ret;
    }

    _tx_stream.remainderHandle = handle;
    _tx_stream.remainderSamps = ret;

    const size_t n = std::min((returnedElems - samp_avail), _tx_stream.remainderSamps);

    writebuf(buffs[0], _tx_stream.remainderBuff, n, _tx_stream.format, samp_avail);
    _tx_stream.remainderSamps -= n;
    _tx_stream.remainderOffset += n;

    if (_tx_stream.remainderSamps == 0)
    {
        this->releaseWriteBuffer(stream, _tx_stream.remainderHandle, _tx_stream.remainderOffset, flags, timeNs);
        _tx_stream.remainderHandle = -1;
        _tx_stream.remainderOffset = 0;
    }

    return returnedElems;
}
