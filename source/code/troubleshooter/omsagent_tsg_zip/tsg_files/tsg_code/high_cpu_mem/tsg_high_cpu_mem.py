from tsg_errors              import is_error, print_errors
from tsg_info                import tsginfo_lookup
from install.tsg_checkoms    import get_oms_version
from install.tsg_install     import check_installation
from connect.tsg_checkendpts import check_log_analytics_endpts
from connect.tsg_connect     import check_connection
from heartbeat.tsg_heartbeat import start_omsagent, check_omsagent_running, check_heartbeat
from .tsg_checkspace         import check_disk_space
from .tsg_checklogrot        import check_log_rotation
from .tsg_checkcpu           import check_omi_cpu
from .tsg_slabmem            import check_slab_memory

def check_high_cpu_memory(prev_success=0):
    print("CHECKING FOR HIGH CPU / MEMORY USAGE...")

    success = prev_success

    # check if installed / connected / running correctly
    print("Checking if omsagent installed and running...")
    # check installation
    if (get_oms_version() == None):
        print_errors(111)
        print("Running the installation part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_installation(err_codes=False, prev_success=101)

    # check connection
    checked_la_endpts = check_log_analytics_endpts()
    if (checked_la_endpts != 0):
        print_errors(checked_la_endpts)
        print("Running the connection part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_connection(err_codes=False, prev_success=101)

    # check running
    checked_omsagent_running = check_omsagent_running(tsginfo_lookup('WORKSPACE_ID'))
    if (checked_omsagent_running != 0):
        print_errors(checked_omsagent_running)
        print("Running the general health part of the troubleshooter in order to find the issue...")
        print("================================================================================")
        return check_heartbeat(prev_success=101)

    # TODO: decide if should keep this in or not
    # check disk space
    # print("Checking recent modifications to largest files...")
    # checked_disk_space = check_disk_space()
    # if (checked_disk_space != 0):
    #     return print_errors(checked_disk_space)

    # check log rotation
    print("Checking if log rotation is working correctly...")
    checked_logrot = check_log_rotation()
    if (is_error(checked_logrot)):
        return print_errors(checked_logrot)
    else:
        success = print_errors(checked_logrot)

    # check CPU capacity
    print("Checking if OMI is at 100% CPU (may take some time)...")
    checked_highcpu = check_omi_cpu()
    if (is_error(checked_highcpu)):
        return print_errors(checked_highcpu)
    else:
        success = print_errors(checked_highcpu)

    # check slab memory / dentry cache issue
    print("Checking slab memory / dentry cache usage...")
    checked_slabmem = check_slab_memory()
    if (is_error(checked_slabmem)):
        return print_errors(checked_slabmem)
    else:
        success = checked_slabmem

    return success