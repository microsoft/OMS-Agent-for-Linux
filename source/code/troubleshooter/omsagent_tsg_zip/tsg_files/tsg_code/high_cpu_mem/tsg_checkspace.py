import os
import subprocess
import time

from tsg_errors import tsg_error_info, get_input



def check_top_files(top_files):
    i = 0
    # loop through all files in top_files
    while (i < len(top_files)):
        # extract info for file
        (fpath, finitsize, fsize, ftime, fchanges) = top_files[i]
        fstat = os.stat(fpath)

        # check if any content modification occurred
        if (fstat.st_mtime != ftime):
            fchanges.append((fstat.st_size-fsize, fstat.st_mtime))
            fsize = fstat.st_size
            ftime = fstat.st_mtime

        # put info back in and continue to next one
        top_files[i] = (fpath, finitsize, fsize, ftime, fchanges)
        i += 1    



def scan_top_files(num_files, tto):
    top_files = []
    print('num_files: {0}, tto: {1}'.format(num_files, tto))
    with open(os.devnull, 'w') as devnull:
        find_cmd = subprocess.Popen(['find','/','-type','f','-exec','du','-S','\{\}','+'],\
                        stdout=subprocess.PIPE, stderr=devnull)
        print('find_cmd: {0}'.format(find_cmd))
        sort_cmd = subprocess.Popen(['sort','-rh'], stdin=find_cmd.stdout, stdout=subprocess.PIPE)
        find_cmd.stdout.close()
        print('sort_cmd: {0}'.format(sort_cmd))
        head_cmd = subprocess.Popen(['head','-n',str(num_files)], stdin=sort_cmd.stdout,\
                        stdout=subprocess.PIPE)
        sort_cmd.stdout.close()
        print('head_cmd: {0}'.format(head_cmd))
        files = head_cmd.communicate()[0]
        print('files: {0}'.format(files))
        # format file list
        parsed_files = files.split('\n')
        print('parsed_files: {0}'.format(parsed_files))

        for f in parsed_files:
            print('f: {0}'.format(f))
            fpath = f.split()[1]
            fstat = os.stat(fpath)
            top_files.append((fpath, fstat.st_size, fstat.st_size, fstat.st_mtime, []))
        # top_files : [ (fpath1, finitsize1, fsize1, ftime1, [ (fsizechange1, fsizechangetime1), ... ]), ... ]

    # check every second
    for sec in range(tto):
        check_top_files(top_files)
        time.sleep(1)

    # go over each file's changes
    result = 0
    for (fpath, finitsize, fsize, ftime, fchanges) in top_files:
        if (fsize > finitsize):
            tsg_error_info.append((fpath, len(fchanges), ftime))
            # TODO: add to file with more info or smth
            result = 151
    return result
        

def check_disk_space():
    print("--------------------------------------------------------------------------------")
    print(" Please input the number of files you want to check, as well as the length of\n"\
          " time you want to observe these files for.")

    def check_int(i):
        try:
            return (int(i) > 0)
        except ValueError:
            return (i == '')

    num_files_in = get_input("How many files do you want to check? (Default is top 20 files)",\
                          check_int,\
                          "Please either type a positive integer, or just hit enter to go\n"\
                            "with the default value.")
    num_files = 20 if (num_files_in == '') else int(num_files_in)
    tto_in = get_input("How many seconds do you want to observe the files? (Default is 60sec)",\
                    check_int,\
                    "Please either type a positive integer, or just hit enter to go\nwith "\
                        "the default value.")
    tto = 60 if (tto_in == '') else int(tto_in)

    # gather info for files
    print("Checking top {0} files for the next {1} seconds...".format(num_files, tto))
    return scan_top_files(num_files, tto)

