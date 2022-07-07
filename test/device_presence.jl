#! /usr/bin/env julia

using Test


"""
Check if there are permission issues with accessing litepci device on the current
system.
"""
function check_device_access()
    @static if Sys.isunix()
        current_user = ENV["USER"]
        in_dialout() || @warn """User $current_user is not in the 'dialout' group.
                                 They can be added with:
                                  'usermod -a -G dialout $current_user'"""
    end
end

"""
On Unix, test if the current user is in the 'dialout' group.
"""
function in_dialout()
    @static if Sys.isunix()
        "dialout" in split(read(`groups`, String))
    end
end

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
    litepcie
    nvidia
    """
    check = String(read(pipeline(`lsmod`, `grep litepcie`, `cut -d' ' -f1`)))
    @test check == expect

    @info "Checking for LiteUART Kernel Modules..."
    expect = """
    liteuart
    """
    check = String(read(pipeline(`lsmod`, `grep liteuart`, `cut -d' ' -f1`)))
    @test check == expect

    @info "Checking for Nvidia Kernel Modules..."
    expect = """
    nvidia_uvm
    nvidia_drm
    nvidia_modeset
    drm_kms_helper
    nvidia
    drm
    """
    check = String(read(pipeline(`lsmod`, `grep nvidia`, `cut -d' ' -f1`)))
    @test check == expect


    @info "Check user groups..."
    check_device_access()
    @test in_dialout()

end

