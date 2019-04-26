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
try:
    import psutil
    from psutil import _pslinux as _psplatform
    import numpy as np
    import msgpack
    from fluent import sender
except Exception as ex:
    print("One of the following python packages is missing:")
    print("numpy, fluent-logger or psutil")
    exit(1)

PY3 = sys.version_info[0] == 3

plugins_config_format = {
    'filter_syslog': """
        <filter oms.syslog.**>
          type filter_syslog
        </filter>
    """,
    'in_dummy': """
       <source>
         @type dummy
         log_level %(log_level)s
         rate %(dummy_eps)s
         auto_increment_key idx
         tag %(tag)s
         dummy {"message":"in_dummy %(dummy_event)s"}
       </source>
   """,
    'in_syslog': """
        <source>
          type syslog
          log_level %(log_level)s
          port %(syslog_port)s
          bind %(syslog_host)s
          protocol_type %(syslog_protocol)s
          tag oms.syslog
        </source>
        <filter oms.syslog.**>
          type filter_syslog
        </filter>
        """,
    'in_security_events': """
        <source>
          type syslog
          log_level %(log_level)s
          port %(security_events_port)s
          bind %(syslog_host)s
          protocol_type %(syslog_protocol)s
          tag oms.security
          format %(CEF_format)s
        </source>
        <filter oms.security.**>
          type filter_syslog_security
        </filter>
    """,
    'in_tcp': """
        <source>
          @type tcp
          log_level %(log_level)s
          tag oms.tcp.events
          format none
          port %(syslog_port)s
          bind %(syslog_host)s
          delimiter \n
        </source>
        """,
    'in_forward': """
        <source>
          @type forward
          log_level %(log_level)s
          port %(fluent_port)s
          bind %(fluent_host)s
        </source>
        """,
    'in_tail': """
        <source>
          type sudo_tail
          log_level %(log_level)s
          path %(tail_path)s
          pos_file %(tail_path)s.pos
          read_from_head %(tail_read_from_head)s
          run_interval %(tail_run_interval)s
          tag oms.blob.CustomLog.CUSTOM_LOG_BLOB.customlog_CL_13a39935-8f3b-43f5-85f3-28c2d8ec4000.*
          format none
        </source>
        """,
    'out_stdout': """
        <match **>
          type stdout
        </match>
        """,
    'out_null': """
        <match **>
          type null
        </match>
        """,
    'out_file': """
        <match oms.**>
          type file
          log_level %(log_level)s
          path %(out_file_path)s
          num_threads %(nb_out_threads)s

          buffer_type file
          buffer_path %(test_dir)s/out_file.*.buffer

          buffer_chunk_limit 10m
          buffer_queue_limit 10
          buffer_queue_full_action drop_oldest_chunk
          flush_interval %(buffer_flush_interval)s
          retry_limit %(retry_limit)s
          retry_wait 5s
          max_retry_wait 9m
          flush_at_shutdown true
        </match>
        """,
    'out_oms': """
        <match oms.**>
          type out_oms
          log_level %(log_level)s
          num_threads %(nb_out_threads)s

          omsadmin_conf_path %(omsadmin_conf_path)s
          cert_path %(cert_path)s
          key_path %(key_path)s

          buffer_type file
          buffer_path %(test_dir)s/out_oms_1*.buffer

          buffer_chunk_limit 15m
          buffer_queue_limit 10
          buffer_queue_full_action drop_oldest_chunk
          flush_interval %(buffer_flush_interval)s
          retry_limit %(retry_limit)s
          retry_wait 30s
          max_retry_wait 9m
          flush_at_shutdown true
        </match>
        """,
    'out_oms_blob': """
        <match oms.blob.**>
          type out_oms_blob
          log_level %(log_level)s
          num_threads %(nb_out_threads)s

          omsadmin_conf_path %(omsadmin_conf_path)s
          cert_path %(cert_path)s
          key_path %(key_path)s

          buffer_type file
          buffer_path %(test_dir)s/out_oms_blob*.buffer

          buffer_chunk_limit 10m
          buffer_queue_limit 10
          buffer_queue_full_action drop_oldest_chunk
          flush_interval %(buffer_flush_interval)s
          retry_limit %(retry_limit)s
          retry_wait 5s
          max_retry_wait 9m
          flush_at_shutdown true
        </match>
        """,
}


def gethostname():
    try:
        return socket.gethostname()
    except Exception:
        return '-'


def build_random_msg_string(size):
    return 'msg_' + ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(size))


def get_all_plugins_name():
    return plugins_config_format.keys()


def get_ruby_version(path):
    cmd = '%s --version' % path
    lines = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.readlines()
    return lines[0].split(' ')[1]


def net_connections(protocol='udp'):
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
                threads['%s-%d' % (proc.name(), t.id)] = round(total_percent * ((t.system_time + t.user_time)/total_time), 2)
            except psutil.NoSuchProcess:
                pass
    return threads


def measure(process, cpu_interval=0.1):
    result = dict()
    result['cpu'] = process.cpu_percent(cpu_interval)
    mem = vars(process.memory_info())
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


def profile(processes, profiler, cpu_interval=0.1):
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


class ForwardWriter(OutputWriter):
    def __init__(self, tag, path, msg_size):
        OutputWriter.__init__(self, 'in_forward', tag, path, msg_size)
        self.protocol = 'tcp'
        self.host, port = self.path.split(':')
        self.port = int(port)
        self.fluent_sender = sender.FluentSender(self.tag, host=self.host, port=self.port)
        self.msgpack_msg = msgpack.packb((self.tag, int(time.time()), self.msg), **{})

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
        if override_buffer is not None:
            self.msg = override_buffer
            self.msgpack_msg = msgpack.packb((self.tag, int(time.time()), self.msg), **{})

        for i in range(eps):
            self.fluent_sender._send_internal(self.msgpack_msg)


class TailFileWriter(OutputWriter):
    def __init__(self, tag, path, msg_size):
        OutputWriter.__init__(self, 'in_tail', tag, path, msg_size)
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
        OutputWriter.__init__(self, 'in_syslog', tag, path, msg_size)
        self.host, port = self.path.split(':')
        self.port = int(port)
        self.protocol = protocol
        self.logger = None
        self.include_counter = True

    def get_address(self):
        return self.host, self.port

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

            self.logger = logging.getLogger('omstest')
            self.logger.setLevel(logging.INFO)
            self.logger.addHandler(self.get_syslog_handler(self.get_address(), socktype))
        return self.logger

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
        if override_buffer is not None:
            self.msg = override_buffer

        logger = self.get_logger()
        for i in range(eps):
            msg = 'idx=%d %s %s' % (self.index, self.get_name(), self.msg) if self.include_counter else self.msg
            msg += '\n'
            logger.log(logging.INFO, msg)
            self.index += 1


class CEFWriter(SyslogWriter):
    CEF_SAMPLE = '0|Palo Alto Networks|PAN-OS|8.0.0|general|SYSTEM|3|rt=Nov 04 2018 07:15:46 GMT deviceExternalId=unknown cs3Label=Virtual System cs3= fname= flexString2Label=Module flexString2=general msg= Failed password for root from 116.31.116.38 port 63605 ssh2 externalId=5705651 cat=general PanOSDGl1=0 PanOSDGl2=0 PanOSDGl3=0 PanOSDGl4=0 PanOSVsysName= dvchost=palovmfw PanOSActionFlags=0x0'

    def __init__(self, tag, path, msg_size, protocol):
        SyslogWriter.__init__(self, tag, path, msg_size, protocol)
        self.include_counter = False
        self.name = 'in_security_events'
        self.msg = self.CEF_SAMPLE

    def get_syslog_handler(self, address, socktype):
        syslog_handler = MySysLogHandler(address=address, socktype=socktype)
        syslog_handler.setFormatter(CEFFormatter())
        return syslog_handler


class TcpWriter(SyslogWriter):
    def __init__(self, tag, path, msg_size):
        SyslogWriter.__init__(self, tag, path, msg_size, 'tcp')
        self.name = 'in_tcp'


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
        self.SYSLOG_PATH = '%(syslog_host)s:%(syslog_port)s' % constants
        self.SECURITY_PATH = '%(syslog_host)s:%(security_events_port)s' % constants
        self.FLUENT_PATH = '%(fluent_host)s:%(fluent_port)s' % constants
        self.TAIL_PATH = '%(tail_path)s' % constants
        self.TESTING_FOLDER_PATH = constants['test_dir']
        self.event_size = int(constants['event_size'])
        self.constants['dummy_event'] = build_random_msg_string(self.event_size)

        self.available_writers = [
            SyslogWriter(self.tag, self.SYSLOG_PATH, self.event_size, constants['syslog_protocol']),
            CEFWriter(self.tag, self.SECURITY_PATH, self.event_size, constants['syslog_protocol']),
            TailFileWriter(self.tag, self.TAIL_PATH, self.event_size),
            ForwardWriter(self.tag, self.FLUENT_PATH, self.event_size),
            TcpWriter(self.tag, self.SYSLOG_PATH, self.event_size)
        ]

    def get_writers_by_name(self, names):
        writers = []

        for writer in self.available_writers:
            if writer.get_name() in names:
                writers.append(writer)

        if len(writers) == 0:
            print("Warning: No writers was found for these plugins '%s'" % ", ".join(names))
        return writers

    def create_oms_config_file(self, plugins):
        path = self.constants['omsagent_config_path']
        plugins_configuration = {}
        for plugin_name, fmt in plugins_config_format.iteritems():
            plugins_configuration[plugin_name] = fmt % self.constants

        dirname = os.path.dirname(path)
        if not os.path.exists(dirname):
            os.makedirs(dirname)

        with open(path, "w", ) as myfile:
            for name in plugins:
                if name in plugins_configuration:
                    myfile.write(plugins_configuration[name])
                else:
                    print("Warning plugin '%s' was not found, will be ignored" % name)


class LoadBench:
    def __init__(self, run_time, sampling_rate, config_mgr):
        self.run_time = run_time
        self.sampling_rate = sampling_rate
        self.config_mgr = config_mgr
        self.stats_logs = [
            '/var/opt/microsoft/omsagent/log/stats_in_dummy.log',
            '/var/opt/microsoft/omsagent/log/stats_out_oms_blob.log',
            '/var/opt/microsoft/omsagent/log/stats_out_oms.log',
            '/var/opt/microsoft/omsagent/log/stats_in_sudo_tail.log',
            '/var/opt/microsoft/omsagent/log/stats_in_syslog.log'
        ]
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

            lines.append('--------------- Stats files ----------------\n')
            for stats_filename in self.stats_logs:
                lines.append(stats_filename + ' :\n')
                with open(stats_filename, "r") as f_stats:
                    lines += f_stats.readlines()
            lines.append('--------------- Test dir ----------------\n')
            listing_files = 'ls -la %s' % self.config_mgr.TESTING_FOLDER_PATH
            content = subprocess.Popen(listing_files.split(' '), stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT).stdout.readlines()
            lines += content
            lines.append('--------------- Sampling ------------------\n')
            lines.append('sampling\t: %s\n' % json.dumps(sampling, ensure_ascii=True))
            f.writelines(lines)

    def reset_workspace(self):
        os.system("sudo mkdir -p %s" % self.config_mgr.TESTING_FOLDER_PATH)
        os.system("sudo chmod 777 -R  %s" % self.config_mgr.TESTING_FOLDER_PATH)
        os.system("sudo rm -rf %s/* " % self.config_mgr.TESTING_FOLDER_PATH)

        for stats_file in self.stats_logs:
            os.system(("echo > %s" % stats_file))

    def parse_stats_files(self):
        stats = {}
        for stats_file in self.stats_logs:
            filename = os.path.splitext(os.path.basename(stats_file))[0]
            stats[filename] = {}
            with open(stats_file, "r") as f:
                for line in f.readlines():
                    line = line.strip('').strip('\n')
                    if line is '':
                        continue
                    try:
                        json_stat = json.loads(line)
                        if json_stat['msg'] == 'success':
                            for name, val in json_stat.iteritems():
                                if name == 'msg':
                                    continue
                                if name not in stats[filename]:
                                    stats[filename][name] = []
                                stats[filename][name].append(json_stat[name])
                        else:
                            print(json_stat)
                    except Exception as e:
                        pass
        return stats

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
        profiler = {}

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

            if round(elapsed_time - previous_elapsed_time, 1) > 1:
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
        header_list = ['ruby', 'res', 'proc', 'plugins', 'eps', 'run_time', 'out_threads', 'perf_tuning',
                       'avg_cpu', 'max_cpu', 'avg_mem', 'max_mem', 'last_mem', 'minor_flt', 'major_flt', 'nb_events',
                       'drops']

        with open(path, "a") as csvfile, open(path + '.json', 'a') as jsonfile:
            # json
            jsonfile.write(json.dumps(results, ensure_ascii=True))
            # csv
            lines = []
            stats_header = []
            # compute stats
            stats_entries = []
            for out_plugin, stats in results['plugin_stats'].iteritems():
                for stats_name, values in stats.iteritems():
                    if 'time' in stats_name:
                        stats_entries.append(int(np.mean(values)) if len(values) > 0 else 0)
                        stats_name = stats_name + '_avg'
                    else:
                        stats_entries.append(int(np.sum(values)))
                    stats_header.append(stats_name)

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
                line = ('"%s", "%s" ,"%s", "%s", %d, %s, %s, "%s", %.2f, %.2f, %d, %d, %d, %d, %d, %d, %s, %s\n' %
                        (
                        results['ruby'], get_resources(), procname, results['plugins'], results['eps'], results['run_time'],
                        results['nb_out_threads'], results['perf_tuning'], avg_cpu, max_cpu, avg_mem, max_mem, last_mem,
                        minor_flt, major_flt, results['nb_events'], drops, stats_line))
                lines.append(line)

                for tid, thread_sampling in sampling['threads'].iteritems():
                    lines.append('"%s", %.2f, %.2f\n' % (tid, np.mean(thread_sampling), max(thread_sampling)))

            if write_header:
                header = "%s\n" % ','.join(header_list + stats_header)
                csvfile.write(header)
            csvfile.writelines(lines)


RUBY_ENV_CONFIG = {
    'none': {},
    'jemalloc': {
        'LD_PRELOAD': '/usr/lib/x86_64-linux-gnu/libjemalloc.so.1'
    },
    'gc_env': {
        "RUBY_GC_HEAP_GROWTH_FACTOR": 1.1,
        "RUBY_GC_MALLOC_LIMIT": 4000100,
        "RUBY_GC_MALLOC_LIMIT_MAX": 16000100,
        "RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR": 1.1,
        "RUBY_GC_OLDMALLOC_LIMIT": 16000100,
        "RUBY_GC_OLDMALLOC_LIMIT_MAX": 16000100,
        "RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR": 0.9,
    },
    'gc_env_2': {
        "RUBY_GC_HEAP_GROWTH_FACTOR": 1.1,
        "RUBY_GC_MALLOC_LIMIT": 1000100,
        "RUBY_GC_MALLOC_LIMIT_MAX": 4000100,
        "RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR": 1.1,
        "RUBY_GC_OLDMALLOC_LIMIT": 4000100,
        "RUBY_GC_OLDMALLOC_LIMIT_MAX": 4000100,
        "RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR": 0.9,
    }
}

WORKSPACE_DIR = './workspace'
TEST_DIR = os.path.join(WORKSPACE_DIR, 'test_dir')
RUBY_PATH_OMS = "/opt/microsoft/omsagent/ruby/bin/ruby"
RUBY_PATH_DEFAULT = "/usr/bin/ruby"
RUBY_PATH_LOCAL = "/usr/local/bin/ruby --jit"
RUBY_PROF_PATH = "/usr/local/bin/ruby-prof"
DEFAULT_VARS = {
    'tag': 'oms.tag.perf',
    'dummy_rate': '1',
    'log_level': 'debug',
    'ruby_path': RUBY_PATH_OMS,
    'nb_out_threads': '5',
    'CEF_format': '/^(?<time>(?:\w+ +){2,3}(?:\d+:){2}\d+):? ?(?:(?<host>[^: ]+) ?:?)? (?<ident>[a-zA-Z0-9_%\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?: *(?<message>.*)$/',
    'syslog_port': '25224',
    'security_events_port': '25226',
    'syslog_host': '127.0.0.1',
    'syslog_protocol': 'tcp',
    'fluent_port': '24224',
    'fluent_host': '0.0.0.0',
    'retry_limit': '50',
    'buffer_flush_interval': '60s',
    'tail_run_interval': '60',
    'tail_path': '%s/in_tail.log' % TEST_DIR,
    'out_file_path': '%s/out_file.log' % TEST_DIR,
    'test_dir': TEST_DIR,
    'omsadmin_conf_path': '/etc/opt/microsoft/omsagent/conf/omsadmin.conf',
    'cert_path': '/etc/opt/microsoft/omsagent/certs/oms.crt',
    'key_path': '/etc/opt/microsoft/omsagent/certs/oms.key',
    'omsagent_config_path': '%s/omsagent.conf' % WORKSPACE_DIR,
    'omsagent_output_path': '%s/output.log' % WORKSPACE_DIR,
    'omsagent_path': '/opt/microsoft/omsagent/bin/omsagent',
    'result_path': '%s/results.csv' % WORKSPACE_DIR,
    'wait_time_after_completion': '5',
    'tail_read_from_head': 'true',
    'perf_tuning': 'none',
    'event_size': '1000',
    'network_queue': '21299',
}

config_path_to_check = ['ruby_path', 'omsadmin_conf_path', 'cert_path', 'key_path', 'omsagent_path']

oms_setups_cmds = [
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
    parser.add_argument("--pgrep", required=False, help="process name to collect metrics", default='')
    parser.add_argument("--rubyprof", required=False, type=bool, help="enable cpu profiling", default=False)
    parser.add_argument("--stackprof", required=False, type=bool, help="enable cpu profiling", default=False)
    parser.add_argument("--plugins", required=False,
                        help="choose which plugins to enable, available plugins: %s" % ','.join(get_all_plugins_name()),
                        default='')

    args, unknown = parser.parse_known_args()
    if len(unknown) > 0:
        print("unknown args:", unknown)
    args = vars(args)

    paths_not_exists = []
    for name in DEFAULT_VARS.keys():
        if name in args and args[name] is not None:
            DEFAULT_VARS[name] = args[name]

        if name in config_path_to_check and name.endswith('_path') and not os.path.exists(DEFAULT_VARS[name]):
            paths_not_exists.append(DEFAULT_VARS[name])

    if len(paths_not_exists) > 0:
        print("Error: these paths don't exist, canceling load: %s" % ',\n '.join(paths_not_exists))
        return

    rubyprof = args['rubyprof']
    stackprof = args['stackprof']
    eps = args['eps']
    DEFAULT_VARS['dummy_eps'] = str(eps)
    run_time = args['run_time']
    plugins = filter(None, args['plugins'].split(','))
    rate = args['sample_rate']
    pids = map(int, filter(None, args['pids'].split(',')))

    if args['pgrep'] is not '':
        list_pids = subprocess.Popen(('pgrep %s' % args['pgrep']).split(' '), stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT).stdout.readlines()
        pids += [int(p.strip('\n')) for p in list_pids]

    run_cmds(network_setups_cmds)
    spawn_new_process = not any(pids)
    config_mgr = ConfigManager(DEFAULT_VARS)
    loadbench = LoadBench(run_time, rate, config_mgr)

    if spawn_new_process:
        if not any(plugins):
            raise Exception("No plugin was provided: plz use --plugins arguments to set input and output plugins")
        environments = {}
        cmd_fmt = "%(ruby_path)s %(omsagent_path)s --no-supervisor -c %(omsagent_config_path)s -o %(omsagent_output_path)s"
        if rubyprof:
            os.system('mkdir -p ./omsperf')
            cmd_fmt = "/usr/local/bin/ruby-prof --mode=cpu -p multi --file=./omsperf %(omsagent_path)s -- --no-supervisor -c %(omsagent_config_path)s -o %(omsagent_output_path)s"
        elif stackprof:
            cmd_fmt = "./stackprof.rb %(omsagent_path)s --no-supervisor -c %(omsagent_config_path)s -o %(omsagent_output_path)s"

        proc = ProcessWrapper(cmd_fmt, DEFAULT_VARS)
        for perf_tuning in args['perf_tuning'].split(','):
            if perf_tuning in RUBY_ENV_CONFIG:
                environments.update(RUBY_ENV_CONFIG[perf_tuning])

        run_cmds(oms_setups_cmds)
        config_mgr.create_oms_config_file(plugins)
        print("CMD:%s" % proc.get_cmd())
        pids = [proc.start_process(envs=environments)]

    plugin_names = '|'.join(plugins)
    processes = map(psutil.Process, pids)
    writers = config_mgr.get_writers_by_name(plugins)

    print("Run load [%s], plugins '%s', %d EPS" % (get_resources(), plugin_names, eps))
    print("Monitoring process : %s" % ', '.join(['%s-%d' % (p.name(), p.pid) for p in processes]))

    profiling, response_times, nb_events = loadbench.run_load(eps, processes, writers)
    wait_time_after_completion = int(config_mgr.constants['wait_time_after_completion'])
    if spawn_new_process:
        # Gracefully terminate processes
        for proc in processes:
            if proc.is_running():
                proc.send_signal(psutil.signal.SIGTERM)

        elapsed_time = 0.0
        if wait_time_after_completion > run_time:
            wait_time_after_completion = run_time / 2

        print("Waiting %d seconds after completion" % wait_time_after_completion)
        while elapsed_time < wait_time_after_completion:
            begin_time = time.time()
            loadbench.save_test_status('wait_time_after_completion', elapsed_time, profiling)
            time.sleep(5)
            elapsed_time += (time.time() - begin_time)
        # cleanup created process
        os.system(("sudo kill -9 %s" % ' '.join(map(str, pids))))
    else:
        print("Waiting %d seconds after completion" % wait_time_after_completion)
        time.sleep(wait_time_after_completion)

    plugin_stats = loadbench.parse_stats_files()
    dropped_events = ['%s:%d' % (w.get_protocol(), w.get_number_dropped_event()) for w in writers]

    result = {
        'ruby': get_ruby_version(config_mgr.constants['ruby_path']),
        'perf_tuning': config_mgr.constants['perf_tuning'],
        "eps": eps,
        "sampling_rate": rate,
        "run_time": run_time,
        'nb_out_threads': config_mgr.constants['nb_out_threads'],
        'profiling': profiling,
        'response_times': response_times,
        'plugins': plugin_names,
        'nb_events': nb_events,
        'plugin_stats': plugin_stats,
        'drops': dropped_events
    }

    print("Response times: avg=%.2f s, max=%.2fs" % (np.mean(response_times), max(response_times)))
    loadbench.save_results(result)


if __name__ == "__main__":
    main(sys.argv[1:])
