import os

from litex.build import tools

from litex.soc.integration.export import get_csr_header, get_soc_header, get_mem_header

from litepcie.software import copy_litepcie_software

def generate_litepcie_software_headers(soc, dst):
    csr_header = get_csr_header(soc.csr_regions, soc.constants, with_access_functions=False)
    tools.write_to_file(os.path.join(dst, "csr.h"), csr_header)
    soc_header = get_soc_header(soc.constants, with_access_functions=False)
    tools.write_to_file(os.path.join(dst, "soc.h"), soc_header)
    mem_header = get_mem_header(soc.mem_regions)
    tools.write_to_file(os.path.join(dst, "mem.h"), mem_header)

def generate_litepcie_software(soc, dst, use_litepcie_software=False):
    if use_litepcie_software:
        gen_module_dir = os.path.join(dst, "kernel")
        our_module_dir = os.path.join(dst, "litepcie-kernel-module")
        gen_user_dir = os.path.join(dst, "user")
        our_user_dir = os.path.join(dst, "litepcie-user-library")
        cdir = os.path.abspath(os.path.dirname(__file__))
        os.system(f"cp {cdir}/__init__.py {cdir}/__init__.py.orig")
        copy_litepcie_software(dst)
        os.system(f"mv -f {gen_module_dir} {our_module_dir}")
        os.system(f"mv -f {gen_user_dir} {our_user_dir}")
        os.system(f"cp {cdir}/__init__.py.orig {cdir}/__init__.py")
    generate_litepcie_software_headers(soc, our_module_dir)
