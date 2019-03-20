#! /usr/bin/env python

import time
import os
import logging
import logging.handlers
import socket
import subprocess
import string
import random
import json
import argparse
import sys
import datetime
import multiprocessing

try:
    import psutil
    from psutil import _pslinux as _psplatform
    import numpy as np
    import msgpack
    from fluent import sender
except Exception as ex:
    print("One of the following python packages is missing:")
    print("numpy fluent-logger psutil")
# from syslog_rfc5424_formatter import RFC5424Formatter
PY3 = sys.version_info[0] == 3

plugins_config_format = {
    'in_syslog': """
        <source>
          type syslog
          log_level %(log_level)s
          port %(syslog_port)s
          bind %(syslog_host)s
          protocol_type %(syslog_protocol)s
          tag oms.syslog
          format none
          allow_without_priority true
        </source>
        <filter oms.syslog.**>
          type filter_syslog
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
          tag oms.blob.CustomLog.CUSTOM_LOG_BLOB.test_tail
          format none
        </source>
        """,
    'out_stdout': """
        <match **>
          type stdout
        </match>
        """,
    'out_file': """
        <match oms.**>
          type file
          log_level %(log_level)s
          path %(out_file_path)s
          num_threads %(nb_out_threads)s
          
          buffer_type file
          buffer_path %(test_dir)s/out_file*.buffer
        
          buffer_chunk_limit 10m
          buffer_queue_limit 10
          buffer_queue_full_action drop_oldest_chunk
          flush_interval %(buffer_flush_interval)s
          retry_limit 10
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
        
          buffer_chunk_limit 5m
          buffer_queue_limit 10
          buffer_queue_full_action drop_oldest_chunk
          flush_interval %(buffer_flush_interval)s
          retry_limit 10
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
          retry_limit 10
          retry_wait 5s
          max_retry_wait 9m
          flush_at_shutdown true
        </match>
        """,

}

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
            try:
                items = line.split()
                sl, laddr, raddr, status, tx_q, rx_q, tr, _, timeout, inode, ref, ptr = items[:12]
                drops = items[-1]
                addr = _psplatform.Connections.decode_address(laddr, socket.AF_INET)
                results.append({
                    'sl': sl, 'laddr': addr, 'drops': int(drops)
                })
            except ValueError:
                raise RuntimeError("error while parsing %s; malformed line %s %r" % (filename, lineno, line))
    return results

def measure_page_faults(pid):
    cmd = 'ps -o min_flt=,maj_flt= -p %s' % pid
    lines = subprocess.Popen(cmd.split(' '), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.readlines()
    output = lines[0].strip('\n').strip().split(' ')
    flts = map(int, filter(None, output))
    return {'minor_flt': flts[0], 'major_flt': flts[1]}

def get_resources():
    cores = multiprocessing.cpu_count()
    ram = psutil.virtual_memory()
    available_mem = ram.available/10**9.0
    total_mem = ram.total/10**9.0
    return '%dCPU| %.1f/%dG RAM' % (cores, available_mem, total_mem)

def measure(process):
    cpu_interval = 0.1
    result = dict()
    result['cpu'] = process.cpu_percent(cpu_interval)
    mem = vars(process.memory_info())
    result.update(mem)

    faults = measure_page_faults(process.pid)
    result.update(faults)

    io = vars(process.io_counters())
    result.update(io)
    # print process.num_ctx_switches()
    # print process.num_threads()
    # print process.threads()
    # print process.connections()
    # print psutil.net_io_counters()
    # print psutil.net_connections()
    # print psutil.net_io_counters(pernic=True, nowrap=False)
    # print result
    return result


def profile(processes, profiler):
    for process in processes:
        key = '%s-%d' % (process.name(), process.pid)
        if key not in profiler:
            profiler[key] = {'cpu': [], 'mem': [], 'minor_flt': [], 'major_flt': []}
        result = measure(process)
        profiler[key]['cpu'].append(result['cpu'])
        profiler[key]['mem'].append(result['rss']/10**6)
        profiler[key]['minor_flt'].append(result['minor_flt'])
        profiler[key]['major_flt'].append(result['major_flt'])
    return profiler


class OutputWriter:
    def __init__(self, name, tag, path, buffer):
        self.index = 0
        self.tag = tag
        self.path = path
        self.buffer = buffer
        self.name = name

    def __str__(self):
        self.name()

    def get_name(self):
        return self.name

    def get_protocol(self):
        return ''

    def write(self, eps):
        print "Not Implemented"

    def get_number_dropped_event(self):
        return 0


class ForwardWriter(OutputWriter):
    def __init__(self, tag, path, log_line):
        OutputWriter.__init__(self, 'in_forward', tag, path, log_line)
        self.protocol = 'tcp'
        self.host, port = self.path.split(':')
        self.port = int(port)
        self.fluent_sender = sender.FluentSender(self.tag, host=self.host, port=self.port)
        self.msgpack_buffer = msgpack.packb((self.tag, int(time.time()), self.buffer), **{})

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
            self.buffer = override_buffer
            self.msgpack_buffer = msgpack.packb((self.tag, int(time.time()), self.buffer), **{})

        for i in range(eps):
            self.fluent_sender._send_internal(self.msgpack_buffer)


class TailFileWriter(OutputWriter):
    def __init__(self, tag, path, log_line):
        OutputWriter.__init__(self, 'in_tail', tag, path, log_line)
        self.max_file_size = 10 * 1024 * 1024 * 1024  # GB

    def get_protocol(self):
        return 'file'

    def write(self, eps, override_buffer=None):
        if override_buffer is not None:
            self.buffer = override_buffer

        if os.path.exists(self.path):
            if os.stat(self.path).st_size > self.max_file_size:
                with open(self.path, "w"):
                    pass
        self.write_in_tail(self.buffer, self.path, eps)

    def write_in_tail(self, line, path, num_lines=1):
        lines = []
        for i in range(num_lines):
            lines.append('%d-%s-%s\n' % (self.index, self.get_name(), line))
            self.index += 1
        with open(path, "a") as myfile:
            myfile.writelines(lines)


class SyslogWriter(OutputWriter):
    def __init__(self, tag, path, log_line, protocol="udp"):
        OutputWriter.__init__(self, 'in_syslog', tag, path, log_line)
        self.host, port = self.path.split(':')
        self.port = int(port)
        self.protocol = protocol
        self.logger = None
        self.write_wait = 0.02
        self.consecutive_write_max = 100

    def get_protocol(self):
        return self.protocol

    def get_logger(self):
        if self.logger is None:
            socktype = socket.SOCK_STREAM if self.protocol.lower() == 'tcp' else socket.SOCK_DGRAM
            self.logger = logging.getLogger('syslogtest')
            self.logger.setLevel(logging.INFO)
            syslog_handler = logging.handlers.SysLogHandler(address=(self.host, self.port), socktype=socktype)
            # syslog_handler.setFormatter(RFC5424Formatter())
            self.logger.addHandler(syslog_handler)
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
            self.buffer = override_buffer

        logger = self.get_logger()
        # wait_counter = 0
        for i in range(eps):
            # if i % self.consecutive_write_max == 0:
            #     wait_counter += 1
            #     time.sleep(self.write_wait)
            logger.info('%d-%s-%s\n' % (self.index, self.get_name(), self.buffer))
            self.index += 1
        # print("wait_counter=%d, time waited %d ms " % (wait_counter, wait_counter*self.write_wait * 1000))


class TcpWriter(SyslogWriter):
    def __init__(self, tag, path, log_line):
        SyslogWriter.__init__(self, tag, path, log_line, 'tcp')
        self.name = 'in_tcp'

class ProcessWrapper:
    def __init__(self, cmd_fmt, cmd_args):
        self.cmd_fmt = cmd_fmt
        self.cmd_args = cmd_args

    def get_cmd(self):
        return self.cmd_fmt % self.cmd_args

    def start_process(self, environments=None, wait_for_steady_stat=3):
        env = {}
        for name, val in environments.iteritems():
            env[name] = str(val)
        popen = subprocess.Popen(self.get_cmd().split(' '), close_fds=True, env=env)
        time.sleep(wait_for_steady_stat)
        return popen.pid


class ConfigManager:
    def __init__(self, constants):
        self.tag = constants['tag']
        self.constants = constants
        self.SYSLOG_PATH = '%(syslog_host)s:%(syslog_port)s' % constants
        self.FLUENT_PATH = '%(fluent_host)s:%(fluent_port)s' % constants
        self.TAIL_PATH = '%(tail_path)s' % constants
        self.TESTING_FOLDER_PATH = constants['test_dir']
        self.event_size = int(constants['event_size'])

        event = self.build_event_string(self.event_size)
        self.available_writers = [
            SyslogWriter(self.tag, self.SYSLOG_PATH, event, constants['syslog_protocol']),
            TailFileWriter(self.tag, self.TAIL_PATH, event),
            ForwardWriter(self.tag, self.FLUENT_PATH, event),
            TcpWriter(self.tag, self.SYSLOG_PATH, event)
        ]

    def build_event_string(self, size):
        return 'Test message: ' + ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(size))

    def get_writer_by_name(self, names):
        writers = []

        for writer in self.available_writers:
            if writer.get_name() in names:
                writers.append(writer)

        if len(writers) == 0:
            print("Warning: No writers found for '%s'" % ", ".join(names))
        return writers

    def create_oms_config_file(self, path, plugins):
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
                    print("Warning plugin '%s' was not found, so it will be ignored" % name)


class LoadTesting:
    def __init__(self, run_time, sampling_rate, config_mgr):
        self.run_time = run_time
        self.sampling_rate = sampling_rate
        self.config_path = './tmp/test.conf'
        self.stdout_path = './tmp/output.log'
        self.result_path = './results.csv'
        self.config_mgr = config_mgr
        self.stats_logs = [
            '/var/opt/microsoft/omsagent/log/stats_out_oms_blob.log',
            '/var/opt/microsoft/omsagent/log/stats_out_oms.log',
            '/var/opt/microsoft/omsagent/log/stats_in_sudo_tail.log',
            '/var/opt/microsoft/omsagent/log/stats_in_syslog.log'
        ]
        self.test_status_path = os.path.join(os.path.dirname(self.config_mgr.constants['result_path']), 'status.txt')

    @staticmethod
    def get_pids(name):
        return map(int, subprocess.check_output(["pidof", name]).split())

    def save_test_status(self, context, elapsed_seconds, sampling):
        lines = []
        with open(self.test_status_path, "w") as f:
            lines.append('context       : %s\n' % context)
            lines.append('status_time   : %s\n' % datetime.datetime.now().time())
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
            content = subprocess.Popen(listing_files.split(' '), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.readlines()
            lines += content
            lines.append('--------------- Sampling ------------------\n')
            lines.append('sampling\t: %s\n' % json.dumps(sampling, ensure_ascii=True))
            f.writelines(lines)

    def reset_workspace(self):
        os.system("sudo /opt/microsoft/omsagent/bin/service_control stop")
        pids = subprocess.Popen('pgrep ruby'.split(' '), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).stdout.readlines()
        if len(pids) > 0:
            os.system("kill -9 %s" % ' '.join(pids))
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

    def run_load(self, eps, proc_wrapper, plugins, environments=None):
        pids = []
        plugin_names = '|'.join(plugins)
        wait_for_completion = int(self.config_mgr.constants['wait_time_after_completion'])

        print("Run load [%s], plugins '%s', %d EPS" % (get_resources(), plugin_names, eps))
        print("CMD='%s'" % proc_wrapper.get_cmd())
        print("Env='%s'" % environments)
        self.reset_workspace()
        self.config_mgr.create_oms_config_file(self.config_mgr.constants['omsagent_config_path'], plugins)

        writers = self.config_mgr.get_writer_by_name(plugins)
        pids.append(proc_wrapper.start_process(environments=environments))
        profiling, response_times, nb_events = self.run_load_for_duration(eps,
                                                                          pids,
                                                                          writers,
                                                                          self.run_time,
                                                                          self.sampling_rate,
                                                                          wait_for_completion)
        dropped_events = ['%s:%d' % (w.get_protocol(), w.get_number_dropped_event()) for w in writers]

        result = {
            'ruby': get_ruby_version(self.config_mgr.constants['ruby_path']),
            'perf_tuning': self.config_mgr.constants['perf_tuning'],
            "eps": eps,
            "sampling_rate": self.sampling_rate,
            "run_time": self.run_time,
            "max_time": max(response_times),
            "avg_time": np.mean(response_times),
            'nb_out_threads': self.config_mgr.constants['nb_out_threads'],
            'profiling': profiling,
            'plugins': plugin_names,
            'nb_events': nb_events,
            'plugin_stats': self.parse_stats_files(),
            'drops': dropped_events
        }

        self.save_results(self.config_mgr.constants['result_path'], [result])
        # cleanup process
        for pid in pids:
            os.system(("sudo kill -9 %d" % pid))
        time.sleep(1)

    def run_load_for_duration(self, eps, pids, writers, run_time, sampling_rate, wait_time_after_completion):
        total_events = run_time*eps
        response_times = [0]
        nb_events = 0
        profiler = {}

        processes = map(psutil.Process, pids)
        profiler = profile(processes, profiler)

        # try:
        elapsed_time = 0.0
        last_profile_time = 0.0
        while nb_events < total_events:
            begin_time = time.time()
            for writer in writers:
                writer.write(eps=eps)
            nb_events += eps
            diff_time = round(time.time() - begin_time, 1)
            response_times.append(diff_time)

            # sleep the rest of the time to complete 1 second
            if diff_time <= 1:
                time.sleep(1 - diff_time)
            else:
                print('Warning: It took more than 1 second to run %d EPS: time=%.2f' % (eps, diff_time))

            elapsed_time += (time.time() - begin_time)
            begin_time = time.time()
            if (elapsed_time - last_profile_time) >= sampling_rate:
                profiler = profile(processes, profiler)
                last_profile_time = elapsed_time
                self.save_test_status('main', elapsed_time, profiler)
            elapsed_time += (time.time() - begin_time)

        # wait more times for collecting more data
        elapsed_time = 0.0
        if wait_time_after_completion > run_time:
            wait_time_after_completion = run_time/2
        while elapsed_time < wait_time_after_completion:
            begin_time = time.time()
            # profiler = profile(processes, profiler)
            self.save_test_status('wait_time_after_completion', elapsed_time, profiler)
            time.sleep(5)
            elapsed_time += (time.time() - begin_time)

        # force flushing
        for proc in processes:
            proc.send_signal(psutil.signal.SIGUSR1)

        # force flushing bu killing process
        for proc in processes:
            proc.send_signal(psutil.signal.SIGTERM)

        # except Exception as e:
        #     print('Exception within run_load_for_duration', e)

        return profiler, response_times, nb_events

    def save_results(self, path, results, write_header=True):
        header_list = ['ruby', 'res', 'proc', 'plugins', 'eps', 'run_time', 'out_threads', 'perf_tuning',
                       'avg_cpu', 'max_cpu', 'avg_mem', 'max_mem', 'last_mem', 'minor_flt', 'major_flt', 'avg_time',
                       'max_time', 'nb_events', 'drops']

        with open(path, "a") as csvfile, open(path+'.json', 'a') as jsonfile:
            # json
            jsonfile.write(json.dumps(results, ensure_ascii=True))
            # csv
            for entry in results:
                lines = []
                stats_header = []
                # compute stats
                stats_entries = []
                for out_plugin, stats in entry['plugin_stats'].iteritems():
                    for stats_name, values in stats.iteritems():
                        if 'time' in stats_name:
                            stats_entries.append(int(np.mean(values)) if len(values) > 0 else 0)
                            stats_name = stats_name + '_avg'
                        else:
                            stats_entries.append(int(np.sum(values)))
                        stats_header.append(stats_name)

                for procname, sampling in entry['profiling'].iteritems():
                    max_cpu = max(sampling['cpu'])
                    avg_cpu = np.mean(sampling['cpu'])
                    last_mem = sampling['mem'][-1]
                    max_mem = max(sampling['mem'])
                    avg_mem = np.mean(sampling['mem'])
                    minor_flt = max(sampling['minor_flt']) - min(sampling['minor_flt'])
                    major_flt = max(sampling['major_flt']) - min(sampling['major_flt'])
                    stats_line = ",".join(map(str, stats_entries))
                    drops = '|'.join(entry['drops']) if len(entry['drops']) > 0 else 0

                    line = ('"%s", "%s" ,"%s", "%s", %d, %s, %s, "%s", %.2f, %.2f, %d, %d, %d, %d, %d, %.3f, %.3f, %d, %s, %s\n' %
                        (entry['ruby'], get_resources(), procname, entry['plugins'], entry['eps'], entry['run_time'],
                        entry['nb_out_threads'], entry['perf_tuning'],
                        avg_cpu, max_cpu, avg_mem, max_mem, last_mem, minor_flt, major_flt, entry['avg_time'],
                        entry['max_time'], entry['nb_events'], drops, stats_line))
                    lines.append(line)

                if write_header:
                    header = "%s\n" % ','.join(header_list+stats_header)
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
RUBY_PATH = "/opt/microsoft/omsagent/ruby/bin/ruby"
DEFAULT_VARS = {
    'tag': 'oms.blob.CustomLog.CUSTOM_LOG_BLOB.profiling',
    'log_level': 'debug',
    'ruby_path': RUBY_PATH,
    'nb_out_threads': '1',
    'syslog_port': '25224',
    'syslog_host': '0.0.0.0',
    'syslog_protocol': 'udp',
    'fluent_port': '24224',
    'fluent_host': '0.0.0.0',
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
    'wait_time_after_completion': '300',
    'tail_read_from_head': 'true',
    'perf_tuning': 'none',
    'event_size': '1000',
    'network_queue': '1000000000',
}

config_path_to_check = ['ruby_path', 'omsadmin_conf_path', 'cert_path', 'key_path', 'omsagent_path']


def setups():
    cmds_setups = [
        'sudo /opt/microsoft/omsagent/bin/service_control stop',
        'sudo /opt/microsoft/omsagent/bin/service_control disable',
        'sudo /opt/microsoft/omsconfig/Scripts/OMS_MetaConfigHelper.py --disable',
        'sudo rm /etc/opt/omi/conf/omsconfig/configuration/Current.mof*',
        'sudo rm /etc/opt/omi/conf/omsconfig/configuration/Pending.mof*',
        'sysctl -w net.core.rmem_max=%(network_queue)s',
        'sysctl -w net.core.rmem_default=%(network_queue)s',
    ]
    print("Running setups")
    for cmd in cmds_setups:
        cmd = cmd % DEFAULT_VARS
        os.system(cmd)

def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--list-default-val", required=False, action='count', default=0, help="list default values")
    for name, value in DEFAULT_VARS.iteritems():
        parser.add_argument("--%s" % name.replace('_', '-'), required=False, help="%s" % name.replace('_', ' '), default=value)

    args, unknown = parser.parse_known_args()
    args = vars(args)
    if args['list_default_val'] > 0:
        print("\t Available plugins: %s" % (', '.join(get_all_plugins_name())))
        for name, value in DEFAULT_VARS.iteritems():
            print("\t %s='%s'" % (name, value))
        return

    parser.add_argument("-t", "--run-time", required=True, type=int, help="duration of the load in seconds")
    parser.add_argument("--eps", required=True, type=int, help="EPS in seconds")
    parser.add_argument("--sample-rate", required=False, type=int, help="sampling rate in seconds", default=1)
    parser.add_argument("--plugins", required=True, help="choose which plugins to enable, available plugins: %s" % ','.join(get_all_plugins_name()))

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

    eps = args['eps']
    run_time = args['run_time']
    plugins = args['plugins'].split(',')
    rate = args['sample_rate']
    environments = {}
    for perf_tuning in args['perf_tuning'].split(','):
        if perf_tuning in RUBY_ENV_CONFIG:
            environments.update(RUBY_ENV_CONFIG[perf_tuning])

    config_mgr = ConfigManager(DEFAULT_VARS)
    load_testing = LoadTesting(run_time, rate, config_mgr)

    setups()

    cmd_fmt = "%(ruby_path)s %(omsagent_path)s --no-supervisor -c %(omsagent_config_path)s -o %(omsagent_output_path)s"
    proc = ProcessWrapper(cmd_fmt, DEFAULT_VARS)
    load_testing.run_load(eps, proc, plugins, environments)


if __name__ == "__main__":
    main(sys.argv[1:])
