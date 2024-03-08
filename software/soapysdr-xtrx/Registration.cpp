#include <SoapySDR/Registry.hpp>
#include "XTRXDevice.hpp"

static std::vector<SoapySDR::Kwargs> findLiteXXTRX(const SoapySDR::Kwargs &args)
{
	std::vector<SoapySDR::Kwargs> results;

	return results;
}

static SoapySDR::Device *makeLiteXXTRX(const SoapySDR::Kwargs &args)
{
    return new SoapyLiteXXTRX(args);
}

static SoapySDR::Registry registerLiteXXTRX("LiteXXTRX", &findLiteXXTRX, &makeLiteXXTRX, SOAPY_SDR_ABI_VERSION);
