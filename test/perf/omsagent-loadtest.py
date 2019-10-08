#! /usr/bin/env python

import sys
import os
import re
import json
import time
import socket
import logging
import string
import random
import argparse
import datetime
import subprocess
import multiprocessing
import logging.handlers
from datetime import datetime
from logging.handlers import SysLogHandler

import psutil
import numpy as np
PY3 = sys.version_info[0] == 3

def gethostname():
    try:
        return socket.gethostname()
    except Exception:
        return '-'


def build_random_msg_string(size):
    return 'msg_' + ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(size))


def get_all_plugins_name():
    return ['syslog', 'syslog_cef', 'file', 'msgpack']


def get_ruby_version(path):
    if not os.path.isfile(path):
        return ''
    cmd = '%s --version' % path
    lines = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.readlines()
    return lines[0].split(' ')[1]


def net_connections(protocol='udp'):
    from psutil import _pslinux as _psplatform
    """Parse /proc/net/tcp* and /proc/net/udp* files."""
    BIGFILE_BUFFERING = -1 if PY3 else 8192
    filename = "/proc/net/%s" % protocol
    results = []
    with open(filename, "rt", buffering=BIGFILE_BUFFERING) as f:
        f.readline()  # skip the first line
        for lineno, line in enumerate(f, 1):
            # try:
            items = line.split()
            sl, laddr, raddr, status, tx_q, rx_q, tr, _, timeout, inode, ref, ptr = items[:12]
            drops = int(items[-1]) if items[-1].isdigit() else 0
            addr = _psplatform.Connections.decode_address(laddr, socket.AF_INET)
            results.append({
                'sl': sl, 'laddr': addr, 'drops': drops
            })
            # except ValueError:
            #     raise RuntimeError("error while parsing %s; malformed line %s %r" % (filename, lineno, line))
    return results


def measure_page_faults(pid):
    flts = [0, 0]
    cmd = 'ps -o min_flt=,maj_flt= -p %s' % pid
    lines = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.readlines()
    if any(lines):
        output = lines[0].strip('\n').strip().split(' ')
        flts = map(int, filter(None, output))
    return {'minor_flt': flts[0], 'major_flt': flts[1]}


def get_resources():
    cores = multiprocessing.cpu_count()
    ram = psutil.virtual_memory()
    available_mem = ram.available / 10 ** 9.0
    total_mem = ram.total / 10 ** 9.0
    return '%dCPU| %.1f/%dG RAM' % (cores, available_mem, total_mem)


def get_threads_cpu_percent(p, total_percent):
    threads = {}
    if p.num_threads() > 1:
        total_time = sum(p.cpu_times())
        for t in p.threads():
            try:
                proc = psutil.Process(t.id)
                thread_time = round(total_percent * ((t.system_time + t.user_time)/total_time), 2) if total_time > 0 else 0
                threads['%s-%d' % (proc.name(), t.id)] = thread_time
            except psutil.NoSuchProcess:
                pass
    return threads


def measure(process, cpu_interval=0):
    result = dict()
    result['cpu'] = process.cpu_percent(cpu_interval)
    mem = vars(process.memory_full_info())
    result.update(mem)
    # faults = measure_page_faults(process.pid)
    # result.update(faults)
    # io = vars(process.io_counters())
    # result.update(io)
    return result


def find_children_processes(processes):
    children = []
    ignore_proc = ['sh', 'sudo']
    for process in processes:
        if process.is_running():
            children += process.children(recursive=True)

    for child in children:
        if child.is_running() and child.name() not in ignore_proc:
            # os.system("pstree -p -t %d" % child.pid)
            processes.append(child)

    return list(set(processes))


def profile(processes, profiler, cpu_interval=0):
    terminated_processes = []
    for process in processes:
        try:
            if not process.is_running():
                raise psutil.NoSuchProcess(process.pid, '')

            key = '%s-%d' % (process.name(), process.pid)
            if key not in profiler:
                profiler[key] = {'cpu': [], 'mem': [], 'minor_flt': [], 'major_flt': [], 'threads': {}}
            result = measure(process, cpu_interval)
            profiler[key]['cpu'].append(result['cpu'])
            profiler[key]['mem'].append(result['rss'] / 10 ** 6)
            # profiler[key]['mem'].append(result['pss'] / 10 ** 6)
            # profiler[key]['minor_flt'].append(result['minor_flt'])
            # profiler[key]['major_flt'].append(result['major_flt'])

            for tid, value in get_threads_cpu_percent(process, result['cpu']).iteritems():
                if tid not in profiler[key]['threads']:
                    profiler[key]['threads'][tid] = []

                profiler[key]['threads'][tid].append(value)
        except psutil.NoSuchProcess:
            terminated_processes.append(process)

    for p in terminated_processes:
        processes.remove(p)
    return processes, profiler


class OutputWriter:
    def __init__(self, name, tag, path, msg_size):
        self.index = 0
        self.tag = tag
        self.path = path
        self.msg_size = msg_size
        self.name = name
        self.msg = build_random_msg_string(self.msg_size)

    def __str__(self):
        self.name()

    def get_name(self):
        return self.name

    def get_protocol(self):
        return ''

    def write(self, eps):
        print("Not Implemented")

    def get_number_dropped_event(self):
        return 0


class MsgPackWriter(OutputWriter):
    def __init__(self, tag, path, msg_size):
        OutputWriter.__init__(self, 'msgpack', tag, path, msg_size)
        self.protocol = 'tcp'
        self.host, port = self.path.split(':')
        self.port = int(port)
        self.fluent_sender = None

    def get_protocol(self):
        return self.protocol

    def get_number_dropped_event(self):
        dropped_events = 0
        list_conn = net_connections(self.protocol)
        for conn in list_conn:
            addr = conn['laddr']
            if addr.ip == self.host and addr.port == self.port:
                dropped_events = conn['drops']
                break
        return dropped_events

    def write(self, eps, override_buffer=None):
        import msgpack
        from fluent import sender
        if self.fluent_sender is None:
            self.fluent_sender = sender.FluentSender(self.tag, host=self.host, port=self.port)
        self.msgpack_msg = msgpack.packb((self.tag, int(time.time()), self.msg), **{})

        if override_buffer is not None:
            self.msg = override_buffer
            self.msgpack_msg = msgpack.packb((self.tag, int(time.time()), self.msg), **{})

        for i in range(eps):
            self.fluent_sender._send_internal(self.msgpack_msg)


class TailFileWriter(OutputWriter):
    def __init__(self, tag, path, msg_size):
        OutputWriter.__init__(self, 'file', tag, path, msg_size)
        self.max_file_size = 10 * 1024 * 1024 * 1024  # 10 GB

    def get_protocol(self):
        return 'file'

    def write(self, eps, override_buffer=None):
        if override_buffer is not None:
            self.msg = override_buffer

        if os.path.exists(self.path):
            if os.stat(self.path).st_size > self.max_file_size:
                with open(self.path, "w"):
                    pass
        self.write_in_tail(self.msg, self.path, eps)

    def write_in_tail(self, line, path, num_lines=1):
        lines = []
        for i in range(num_lines):
            lines.append('%d-%s-%s\n' % (self.index, self.get_name(), line))
            self.index += 1
        with open(path, "a") as myfile:
            myfile.writelines(lines)


class RFC5424Formatter(logging.Formatter, object):
    def __init__(self, *args, **kwargs):
        self._tz_fix = re.compile(r'([+-]\d{2})(\d{2})$')
        super(RFC5424Formatter, self).__init__(*args, **kwargs)

    def format(self, record):
        record.__dict__['hostname'] = gethostname()
        isotime = datetime.fromtimestamp(record.created).isoformat()
        tz = self._tz_fix.match(time.strftime('%z'))
        if time.timezone and tz:
            (offset_hrs, offset_min) = tz.groups()
            if int(offset_hrs) == 0 and int(offset_min) == 0:
                isotime = isotime + 'Z'
            else:
                isotime = '{0}{1}:{2}'.format(isotime, offset_hrs, offset_min)
        else:
            isotime = isotime + 'Z'

        record.__dict__['isotime'] = isotime
        header = '1 {isotime} {hostname} {module} {process} - - '.format(**record.__dict__)
        body = super(RFC5424Formatter, self).format(record)
        return (header + body).encode('utf-8')


class RFC3164Formatter(logging.Formatter, object):
    def __init__(self, *args, **kwargs):
        super(RFC3164Formatter, self).__init__(*args, **kwargs)

    def format(self, record):
        record.__dict__['isotime'] = datetime.fromtimestamp(record.created).strftime("%b %d %H:%M:%S")
        record.__dict__['hostname'] = gethostname()
        header = '{isotime} {hostname} {name}[{process}]: '.format(**record.__dict__)
        body = super(RFC3164Formatter, self).format(record)
        return (header + body).encode('ASCII', 'ignore')


# Base CEF format: CEF:Version|Device Vendor|Device Product|Device Version|Signature ID|Name|Severity|Extension
class CEFFormatter(logging.Formatter, object):
    def __init__(self, *args, **kwargs):
        super(CEFFormatter, self).__init__(*args, **kwargs)

    def format(self, record):
        isotime = datetime.fromtimestamp(record.created).strftime("%b %d %H:%M:%S")
        data = '%s %s CEF: %s' % (isotime, gethostname(), super(CEFFormatter, self).format(record))
        return data.encode('ASCII', 'ignore')


class MySysLogHandler(SysLogHandler):
    def __init__(self, address=('localhost', logging.handlers.SYSLOG_UDP_PORT),
                 facility=SysLogHandler.LOG_USER, socktype=None):
        SysLogHandler.__init__(self, address, facility, socktype)
        self.include_priority = True

    def emit(self, record):
        try:
            msg = self.format(record)

            if self.include_priority:
                msg = '<%d>%s' % (self.encodePriority(self.facility, self.mapPriority(record.levelname)), msg)

            if self.unixsocket:
                try:
                    self.socket.send(msg)
                except socket.error:
                    self.socket.close()  # See issue 17981
                    self._connect_unixsocket(self.address)
                    self.socket.send(msg)
            elif self.socktype == socket.SOCK_DGRAM:
                self.socket.sendto(msg, self.address)
            else:
                self.socket.sendall(msg)
        except (KeyboardInterrupt, SystemExit):
            raise
        except:
            self.handleError(record)


class SyslogWriter(OutputWriter):
    def __init__(self, tag, path, msg_size, protocol="udp"):
        OutputWriter.__init__(self, 'syslog', tag, path, msg_size)
        self.host = None
        self.port = None
        self.is_unix_socket = (protocol.lower() == 'unix')
        if not self.is_unix_socket:
            self.host, port = self.path.split(':')
            self.port = int(port)
        self.protocol = protocol
        self.logger = None
        self.include_counter = True

    def get_address(self):
        return self.path if self.is_unix_socket else (self.host, self.port)

    def get_protocol(self):
        return self.protocol

    def get_syslog_handler(self, address, socktype):
        syslog_handler = MySysLogHandler(address=address, socktype=socktype)
        syslog_handler.include_priority = True
        syslog_handler.setFormatter(RFC3164Formatter())  # fluentd uses rfc3164 by default
        return syslog_handler

    def get_logger(self):
        if self.logger is None:
            socktype = None
            if self.protocol.lower() == 'tcp':
                socktype = socket.SOCK_STREAM
            elif self.protocol.lower() == 'udp':
                socktype = socket.SOCK_DGRAM
            elif self.protocol.lower() == 'unix':
                socktype = None

            self.logger = logging.getLogger('omstest')
            self.logger.setLevel(logging.DEBUG)
            print(self.get_address())
            self.logger.addHandler(self.get_syslog_handler(self.get_address(), socktype))
        return self.logger

    def get_number_dropped_event(self):
        dropped_events = 0
        if self.is_unix_socket:
            return 0
        list_conn = net_connections(self.protocol)
        for conn in list_conn:
            addr = conn['laddr']
            if addr.ip == self.host and addr.port == self.port:
                dropped_events = conn['drops']
                break
        return dropped_events

    def write(self, eps, override_buffer=None):
        if override_buffer is not None:
            self.msg = override_buffer

        logger = self.get_logger()
        for i in range(eps):
            message = 'idx=%d %s %s' % (self.index, self.get_name(), self.msg) if self.include_counter else self.msg
            message += '\n'
            # print(message)
            logger.log(logging.INFO, message)
            self.index += 1


class CEFWriter(SyslogWriter):
    CEF_SAMPLE = '0|omsagent-loadtest|PAN-OS|8.0.0|general|SYSTEM|3|rt=Nov 04 2018 07:15:46 GMT deviceExternalId=unknown cs3Label=Virtual System cs3= fname= flexString2Label=Module flexString2=general msg= Failed password for root from 116.31.116.38 port 63605 ssh2 externalId=5705651 cat=general PanOSDGl1=0 PanOSDGl2=0 PanOSDGl3=0 PanOSDGl4=0 PanOSVsysName= dvchost=palovmfw PanOSActionFlags=0x0'

    def __init__(self, tag, path, msg_size, protocol):
        SyslogWriter.__init__(self, tag, path, msg_size, protocol)
        self.include_counter = True
        self.name = 'syslog_cef'
        self.msg = self.CEF_SAMPLE

    def get_syslog_handler(self, address, socktype):
        syslog_handler = MySysLogHandler(address=address, socktype=socktype)
        syslog_handler.setFormatter(CEFFormatter())
        return syslog_handler

class TcpWriter(SyslogWriter):
    def __init__(self, tag, path, msg_size):
        SyslogWriter.__init__(self, tag, path, msg_size, 'tcp')
        self.name = 'tcp'

class ProcessWrapper:
    def __init__(self, cmd_fmt, cmd_args):
        self.cmd_fmt = cmd_fmt
        self.cmd_args = cmd_args

    def get_cmd(self):
        return self.cmd_fmt % self.cmd_args

    def start_process(self, envs=None, wait_for_steady_stat=1):
        envs_str = {}
        for name, val in envs.iteritems():
            envs_str[name] = str(val)
        popen = subprocess.Popen(self.get_cmd().split(' '), close_fds=True, env=envs_str)
        time.sleep(wait_for_steady_stat)
        return popen.pid


class ConfigManager:
    def __init__(self, constants):

        self.tag = constants['tag']
        self.constants = constants
        if constants['syslog_protocol'] == 'unix':
            self.SYSLOG_PATH = '%(syslog_path)s' % constants
            self.SECURITY_PATH = '%(syslog_path)s' % constants
        else:
            self.SYSLOG_PATH = '%(syslog_host)s:%(syslog_port)s' % constants
            self.SECURITY_PATH = '%(syslog_host)s:%(syslog_port)s' % constants
        self.FLUENT_PATH = '%(fluent_host)s:%(fluent_port)s' % constants
        self.TAIL_PATH = '%(tail_path)s' % constants
        self.TESTING_FOLDER_PATH = constants['test_dir']
        self.event_size = int(constants['event_size'])
        self.constants['dummy_event'] = build_random_msg_string(self.event_size)

        self.available_writers = [
            SyslogWriter(self.tag, self.SYSLOG_PATH, self.event_size, constants['syslog_protocol']),
            CEFWriter(self.tag, self.SYSLOG_PATH, self.event_size, constants['syslog_protocol']),
            TailFileWriter(self.tag, self.TAIL_PATH, self.event_size),
            MsgPackWriter(self.tag, self.FLUENT_PATH, self.event_size),
            # TcpWriter(self.tag, self.SYSLOG_PATH, self.event_size)
        ]

    def get_writers_by_name(self, names):
        writers = []

        for writer in self.available_writers:
            if writer.get_name() in names:
                writers.append(writer)

        if len(writers) == 0:
            print("Warning: No writers was found for these plugins '%s'" % ", ".join(names))
        return writers



class LoadBench:
    def __init__(self, run_time, sampling_rate, config_mgr):
        self.run_time = run_time
        self.sampling_rate = sampling_rate
        self.config_mgr = config_mgr
        self.do_profiling = True
        self.test_status_path = os.path.join(os.path.dirname(self.config_mgr.constants['result_path']), 'status.txt')

        self.reset_workspace()

    @staticmethod
    def get_pids(name):
        return map(int, subprocess.check_output(["pidof", name]).split())

    def save_test_status(self, context, elapsed_seconds, sampling):
        lines = []
        with open(self.test_status_path, "w") as f:
            lines.append('context       : %s\n' % context)
            lines.append('status_time   : %s\n' % datetime.now().time())
            lines.append('elapsed_time  : %d seconds\n' % elapsed_seconds)
            lines.append('--------------- Configuration ----------------\n')
            for name, value in self.config_mgr.constants.iteritems():
                lines.append("%s\t\t\t: %s\n" % (name, value))
            lines.append('--------------- Test dir ----------------\n')
            listing_files = 'ls -la %s' % self.config_mgr.TESTING_FOLDER_PATH
            content = subprocess.Popen(listing_files.split(' '), stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT).stdout.readlines()
            lines += content
            lines.append('--------------- Sampling ------------------\n')
            lines.append('sampling\t: %s\n' % json.dumps(sampling, ensure_ascii=True))
            f.writelines(lines)

    def reset_workspace(self):
        os.system("mkdir -p %s" % self.config_mgr.TESTING_FOLDER_PATH)
        os.system("sudo chmod 777 -R  %s" % self.config_mgr.TESTING_FOLDER_PATH)
        os.system("sudo rm -rf %s/* " % self.config_mgr.TESTING_FOLDER_PATH)

    def run_load(self, eps, processes, writers):
                return self.run_load_for_duration(eps, processes, writers, self.run_time, self.sampling_rate)

    def clear_dead_process(self, processes):
        terminated_processes = []
        for p in processes:
            if not p.is_running():
                terminated_processes.append(p)

        for p in terminated_processes:
            processes.remove(p)
        return processes

    def run_load_for_duration(self, eps, processes, writers, run_time, sampling_rate):
        total_events = run_time * eps
        response_times = [0]
        nb_events = 0
        profile_diff_time = 0
        profiler = {}

        if self.do_profiling:
            processes, profiler = profile(processes, profiler)

        elapsed_time = 0.0
        last_profile_time = 0.0
        while nb_events < total_events:
            previous_elapsed_time = elapsed_time
            begin_time = time.time()
            for writer in writers:
                writer.write(eps=eps)
            nb_events += eps
            diff_time = round(time.time() - begin_time, 1)
            response_times.append(diff_time)

            elapsed_time += (time.time() - begin_time)
            if self.do_profiling:
                begin_time = time.time()
                if (elapsed_time - last_profile_time) >= sampling_rate:
                    processes = self.clear_dead_process(processes)
                    processes = find_children_processes(processes)
                    processes, profiler = profile(processes, profiler)
                    last_profile_time = elapsed_time
                profile_diff_time = time.time() - begin_time
                elapsed_time += profile_diff_time

            # sleep the rest of the time to complete 1 second
            sleep_time = 1 - diff_time - profile_diff_time - 0.05
            if sleep_time > 0.05:
                begin_time = time.time()
                time.sleep(sleep_time)
                elapsed_time += (time.time() - begin_time)

            if round(elapsed_time - previous_elapsed_time, 2) > 1:
                print('%s: Took more than 1s for %d EPS: total_time=%.3f s, resp_time=%.2f s, profile_time=%.2f s, '
                      'sleep_time=%.2f s' % (datetime.now().time(), eps, elapsed_time - previous_elapsed_time,
                                             diff_time, profile_diff_time, sleep_time))

        self.save_test_status('done', elapsed_time, profiler)
        # wait more times for collecting more data
        # force flushing
        processes = self.clear_dead_process(processes)
        for proc in processes:
            if proc.is_running():
                proc.send_signal(psutil.signal.SIGUSR1)

        return profiler, response_times, nb_events

    def save_results(self, results, write_header=True):
        path = self.config_mgr.constants['result_path']
        header_list = ['res', 'proc', 'plugins', 'eps', 'run_time', 'avg_cpu', 'max_cpu', 'avg_mem', 'max_mem',
        'last_mem', 'minor_flt', 'major_flt', 'nb_events', 'drops']

        with open(path, "a") as csvfile, open(path + '.json', 'a') as jsonfile:
            # json
            jsonfile.write(json.dumps(results, ensure_ascii=True))
            # csv
            lines = []
            stats_header = []
            # compute stats
            stats_entries = []
            for procname, sampling in results['profiling'].iteritems():
                max_cpu = max(sampling['cpu']) if any(sampling['cpu']) else 0
                avg_cpu = np.mean(sampling['cpu']) if any(sampling['mem']) else 0
                last_mem = sampling['mem'][-1] if any(sampling['mem']) else 0
                max_mem = max(sampling['mem']) if any(sampling['mem']) else 0
                avg_mem = np.mean(sampling['mem']) if any(sampling['mem']) else 0
                minor_flt = max(sampling['minor_flt']) - min(sampling['minor_flt']) if any(sampling['minor_flt']) else 0
                major_flt = max(sampling['major_flt']) - min(sampling['major_flt']) if any(sampling['major_flt']) else 0
                stats_line = ",".join(map(str, stats_entries))
                drops = '|'.join(results['drops']) if len(results['drops']) > 0 else 0
                print("%s cpu=%.2f %%, mem=%d MB" % (procname, avg_cpu, avg_mem))
                line = ('"%s" ,"%s", "%s", %d, %s, %.2f, %.2f, %d, %d, %d, %d, %d, %d, %s, %s\n' %
                        (get_resources(), procname, results['plugins'], results['eps'], results['run_time'],
                        avg_cpu, max_cpu, avg_mem, max_mem, last_mem,
                        minor_flt, major_flt, results['nb_events'], drops, stats_line))
                lines.append(line)

                for tid, thread_sampling in sampling['threads'].iteritems():
                    lines.append('"%s", %.2f, %.2f\n' % (tid, np.mean(thread_sampling), max(thread_sampling)))

            if write_header:
                header = "%s\n" % ','.join(header_list + stats_header)
                csvfile.write(header)
            csvfile.writelines(lines)

WORKSPACE_DIR = './workspace'
TEST_DIR = os.path.join(WORKSPACE_DIR, 'test_dir')
RUBY_PATH_OMS = "/opt/microsoft/omsagent/ruby/bin/ruby"
RUBY_PATH_DEFAULT = "/usr/bin/ruby"
RUBY_PATH_LOCAL = "/usr/local/bin/ruby"
RUBY_PROF_PATH = "/usr/local/bin/ruby-prof"
DEFAULT_VARS = {
    'tag': 'oms.tag.perf',
    'syslog_port': '25224',
    'security_events_port': '25226',
    'syslog_path': '%s/in_syslog.socket' % TEST_DIR,
    'syslog_host': '0.0.0.0',
    'syslog_protocol': 'tcp',
    'fluent_port': '24224',
    'fluent_host': '0.0.0.0',
    'tail_path': '%s/in_tail.log' % TEST_DIR,
    'test_dir': TEST_DIR,
    'omsadmin_conf_path': '/etc/opt/microsoft/omsagent/conf/omsadmin.conf',
    'cert_path': '/etc/opt/microsoft/omsagent/certs/oms.crt',
    'key_path': '/etc/opt/microsoft/omsagent/certs/oms.key',
    'omsagent_config_path': '/etc/opt/microsoft/omsagent/conf/omsagent.conf',
    'omsagent_path': '/opt/microsoft/omsagent/bin/omsagent',
    'result_path': '%s/results.csv' % WORKSPACE_DIR,
    'wait_time_after_completion': '0',
    'perf_tuning': 'none',
    'event_size': '1000',
    'network_queue': '21299',
}

disable_oms_dsc_cmds = [
    'sudo /opt/microsoft/omsagent/bin/service_control stop',
    'sudo /opt/microsoft/omsagent/bin/service_control disable',
    'sudo /opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable',
    'sudo rm /etc/opt/omi/conf/omsconfig/configuration/Current.mof*',
    'sudo rm /etc/opt/omi/conf/omsconfig/configuration/Pending.mof*',
]
network_setups_cmds = [
    'sysctl -w net.core.rmem_max=%(network_queue)s',
    'sysctl -w net.core.rmem_default=%(network_queue)s',
]

def run_cmds(cmds):
    for cmd in cmds:
        cmd = cmd % DEFAULT_VARS
        out = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT).stdout.readlines()

def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--list-default-val", required=False, action='count', default=0, help="list default values")
    for name, value in DEFAULT_VARS.iteritems():
        parser.add_argument("--%s" % name.replace('_', '-'), required=False, help="%s" % name.replace('_', ' '),
                            default=value)

    args, unknown = parser.parse_known_args()
    args = vars(args)
    if args['list_default_val'] > 0:
        print("\t Available plugins: %s" % (', '.join(get_all_plugins_name())))
        for name, value in DEFAULT_VARS.iteritems():
            print("\t %s='%s'" % (name, value))
        return

    parser.add_argument("--run-time", required=True, type=int, help="duration of the load in seconds")
    parser.add_argument("--eps", required=False, type=int, help="EPS in seconds", default=1)
    parser.add_argument("--sample-rate", required=False, type=float, help="sampling rate in seconds", default=0.5)
    parser.add_argument("--pids", required=False, help="pids of processes to collect metrics", default='')
    parser.add_argument("--pgrep", required=False, help="process name to collect metrics", default='omsagent')
    parser.add_argument("--do-profiling", required=False, help="", action='store_true')
    parser.add_argument("--plugins", required=False,
                        help="choose which plugins to enable, available plugins: %s" % ','.join(get_all_plugins_name()),
                        default='')

    args, unknown = parser.parse_known_args()
    if len(unknown) > 0:
        print("unknown args:", unknown)
    args = vars(args)

    do_profiling = args['do_profiling']
    for name in DEFAULT_VARS.keys():
        if name in args and args[name] is not None:
            DEFAULT_VARS[name] = args[name]

    eps = args['eps']
    run_time = args['run_time']
    plugins = filter(None, args['plugins'].split(','))
    rate = args['sample_rate']
    pids = map(int, filter(None, args['pids'].split(',')))

    if do_profiling and args['pgrep'] is not '':
        list_pids = subprocess.Popen(('pgrep %s' % args['pgrep']).split(' '), stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT).stdout.readlines()
        pids += [int(p.strip('\n')) for p in list_pids]

    config_mgr = ConfigManager(DEFAULT_VARS)
    loadbench = LoadBench(run_time, rate, config_mgr)
    loadbench.do_profiling = do_profiling

    plugin_names = '|'.join(plugins)
    processes = []
    writers = config_mgr.get_writers_by_name(plugins)

    print("Run load, plugins '%s', %d EPS" % (plugin_names, eps))
    if do_profiling:
        processes = map(psutil.Process, pids)
        print("Monitoring process : %s" % ', '.join(['%s-%d' % (p.name(), p.pid) for p in processes]))

    profiling, response_times, nb_events = loadbench.run_load(eps, processes, writers)
    wait_time_after_completion = int(config_mgr.constants['wait_time_after_completion'])
    if wait_time_after_completion > 0:
        print("Waiting %d seconds after completion" % wait_time_after_completion)
        time.sleep(wait_time_after_completion)

    dropped_events = ['%s:%d' % (w.get_protocol(), w.get_number_dropped_event()) for w in writers]

    print("Response times: avg=%.2f s, max=%.2fs" % (np.mean(response_times), max(response_times)))
    if do_profiling:
        result = {
            "eps": eps,
            "sampling_rate": rate,
            "run_time": run_time,
            'profiling': profiling,
            'response_times': response_times,
            'plugins': plugin_names,
            'nb_events': nb_events,
            'drops': dropped_events
        }
        loadbench.save_results(result)


if __name__ == "__main__":
    main(sys.argv[1:])

