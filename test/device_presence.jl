#! /usr/bin/env julia

using Test

@testset "Device and Kernel Checks" begin
    @info "Checking Kernel Version"
    expect = "5.15.0-39-generic\n"
    check = String(read(`uname -r`))
    @test check == expect

    @info "Checking for XTRX Presence..."
    expect = "02:00.0 Memory controller: Xilinx Corporation Device 7022\n"
    check = String(read(pipeline(`lspci`, `grep 7022`)))
    @test check == expect

    @info "Checking for GPU Presence..."
    expect = """
    01:00.0 VGA compatible controller: NVIDIA Corporation GA102GL [RTX A5000] (rev a1)
    01:00.1 Audio device: NVIDIA Corporation GA102 High Definition Audio Controller (rev a1)
    """
    check = String(read(pipeline(`lspci`, `grep NVIDIA`)))
    @test check == expect

    @info "Checking for LitePCIe Kernel Modules..."
    expect = """
    litepcie               24576  0
    nvidia               4567040  206 litepcie,nvidia_modeset
    """
    check = String(read(pipeline(`lsmod`, `grep litepcie`)))
    @test check == expect

    @info "Checking for LiteUART Kernel Modules..."
    expect = """
    liteuart               16384  0
    """
    check = String(read(pipeline(`lsmod`, `grep liteuart`)))
    @test check == expect

    @info "Checking for Nvidia Kernel Modules..."
    expect = """
    nvidia_drm             69632  3
    nvidia_modeset       1064960  5 nvidia_drm
    drm_kms_helper        307200  1 nvidia_drm
    nvidia               4567040  206 litepcie,nvidia_modeset
    drm                   606208  7 drm_kms_helper,nvidia,nvidia_drm
    """
    check = String(read(pipeline(`lsmod`, `grep nvidia`)))
    @test check == expect

end

