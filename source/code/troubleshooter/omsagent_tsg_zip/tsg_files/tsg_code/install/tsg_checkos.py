# inspired by omsagent.py

from tsg_errors import tsg_error_info
from tsg_info   import get_os_bits, get_os_version

supported_dists = {'redhat' : ['6', '7'], # CentOS
                   'centos' : ['6', '7'], # CentOS
                   'red hat' : ['6', '7'], # Oracle, RHEL
                   'oracle' : ['6', '7'], # Oracle
                   'debian' : ['8', '9'], # Debian
                   'ubuntu' : ['14.04', '16.04', '18.04'], # Ubuntu
                   'suse' : ['12'], 'sles' : ['15'], # SLES
                   'amzn' : ['2017.09']
}



# print out warning if running the wrong version of OS
def get_alternate_versions(supported_dist):
    versions = supported_dists[supported_dist]
    last = versions.pop()
    if (versions == []):
        s = "{0}".format(last)
    else:
        s = "{0} or {1}".format(', '.join(versions), last)
    return s



def check_vm_supported(vm_dist, vm_ver):
    vm_supported = False

    # find VM distribution in supported list
    vm_supported_dist = None
    for supported_dist in (supported_dists.keys()):
        if (not vm_dist.lower().startswith(supported_dist)):
            continue
        
        vm_supported_dist = supported_dist
        # check if version is supported
        vm_ver_split = vm_ver.split('.')
        for supported_ver in (supported_dists[supported_dist]):
            supported_ver_split = supported_ver.split('.')
            vm_ver_match = True
            # try matching VM version with supported version
            for (idx, supported_ver_num) in enumerate(supported_ver_split):
                try:
                    supported_ver_num = int(supported_ver_num)
                    vm_ver_num = int(vm_ver_split[idx])
                    if (vm_ver_num is not supported_ver_num):
                        vm_ver_match = False
                        break
                except (IndexError, ValueError) as e:
                    vm_ver_match = False
                    break
                
            # check if successful in matching
            if (vm_ver_match):
                vm_supported = True
                break

        # check if any version successful in matching
        if (vm_supported):
            return 0

    # VM distribution is supported, but not current version
    if (vm_supported_dist != None):
        alt_vers = get_alternate_versions(vm_supported_dist)
        tsg_error_info.append((vm_dist, vm_ver, alt_vers))
        return 103

    # VM distribution isn't supported
    else:
        tsg_error_info.append((vm_dist,))
        return 104



def check_os():
    # 32 bit or 64 bit
    cpu_bits = get_os_bits()
    if (cpu_bits == None or (cpu_bits not in ['32-bit', '64-bit'])):
        return 102

    # get OS version
    vm_info = get_os_version()
    if (vm_info == None):
        return 105
    
    # check if OS version is supported
    (vm_dist, vm_ver) = vm_info
    return check_vm_supported(vm_dist, vm_ver)