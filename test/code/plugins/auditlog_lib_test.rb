# Copyright (c) Microsoft Corporation. All rights reserved.
require 'test/unit'
require_relative '../../../source/code/plugins/auditlog_lib'

class AuditLogTestRuntimeError < AuditLogModule::LoggingBase
  def log_error(text)
    raise text
  end
end

class AuditLogLib_Test < Test::Unit::TestCase
  class << self
    def startup
      @@auditlog_lib = AuditLogModule::AuditLogParser.new(AuditLogTestRuntimeError.new)
    end

    def shutdown
      #no op
    end
  end

  def test_parse_null_empty
    assert_equal({}, @@auditlog_lib.parse(nil)[1], "null record fails")
    assert_equal({}, @@auditlog_lib.parse("")[1], "empty string record fails")
    assert_raise(RuntimeError, "int should fail") do
      @@auditlog_lib.parse(10)
    end
  end

  def test_parse_syscall
    time, record = @@auditlog_lib.parse('type=SYSCALL msg=audit(1364481363.243:24287): arch=c000003e syscall=2 success=no exit=-13 a0=7fffd19c5592 a1=0 a2=7fffd19c4b50 a3=a items=1 ppid=2686 pid=3538 auid=999 uid=999 gid=999 euid=999 suid=999 fsuid=999 egid=999 sgid=999 fsgid=999 tty=pts0 ses=1 comm="cat" exe="/bin/cat" subj=\'unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023\' key="sshd_config"')

    assert_equal(1364481363.243, time, "time is not correct")
    assert_equal('SYSCALL', record["RecordType"], "RecordType is not correct")
    assert(record.has_key?("Computer"), "Computer is missing")
    assert_equal('1364481363.243:24287', record["AuditID"], "AuditID is not correct")
    assert_equal('2013-03-28T14:36:03.243Z', record["Timestamp"], "Timestamp is not correct")
    assert_equal('24287', record["SerialNumber"], "SerialNumber is not correct")
    assert_equal('c000003e', record["arch"], "arch is not correct")
    assert_equal('2', record["syscall"], "syscall is not correct")
    assert_equal('no', record["success"], "success is not correct")
    assert_equal('-13', record["exit"], "exit is not correct")
    assert_equal('7fffd19c5592', record["a0"], "a0 is not correct")
    assert_equal('0', record["a1"], "a1 is not correct")
    assert_equal('7fffd19c4b50', record["a2"], "a2 is not correct")
    assert_equal('a', record["a3"], "a3 is not correct")
    assert_equal('1', record["items"], "items is not correct")
    assert_equal('2686', record["ppid"], "ppid is not correct")
    assert_equal('3538', record["pid"], "pid is not correct")
    assert_equal('999', record["auid"], "auid is not correct")
    assert_equal('999', record["uid"], "uid is not correct")
    assert_equal('999', record["euid"], "euid is not correct")
    assert_equal('999', record["suid"], "suid is not correct")
    assert_equal('999', record["fsuid"], "fsuid is not correct")
    assert_equal('999', record["egid"], "egid is not correct")
    assert_equal('999', record["sgid"], "sgid is not correct")
    assert_equal('999', record["fsgid"], "fsgid is not correct")
    assert_equal('pts0', record["tty"], "tty is not correct")
    assert_equal('1', record["ses"], "ses is not correct")
    assert_equal('cat', record["comm"], "comm is not correct")
    assert_equal('/bin/cat', record["exe"], "exe is not correct")
    assert_equal('unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023', record["subj"], "subj is not correct")
    assert_equal('sshd_config', record["key"], "key is not correct")
  end

  def test_parse_user_login
    time, record = @@auditlog_lib.parse('type=USER_LOGIN msg=audit(1456377068.691:87): pid=61945 uid=0 auid=1000 ses=1353 msg=\'op=login id=1000 exe="/usr/sb in/sshd" hostname=50.132.33.101 addr=50.132.33.101 terminal=/dev/pts/1 res=success\'')

    assert_equal(1456377068.691, time, "time is not correct")
    assert_equal('USER_LOGIN', record["RecordType"], "RecordType is not correct")
    assert(record.has_key?("Computer"), "Computer is missing")
    assert_equal('1456377068.691:87', record["AuditID"], "AuditID is not correct")
    assert_equal('2016-02-25T05:11:08.690Z', record["Timestamp"], "Timestamp is not correct")
    assert_equal('87', record["SerialNumber"], "SerialNumber is not correct")
    assert_equal('61945', record["pid"], "pid is not correct")
    assert_equal('0', record["uid"], "uid is not correct")
    assert_equal('root', record["user_name"], "user_name is not correct")
    assert_equal('1000', record["auid"], "auid is not correct")
    assert_equal('1353', record["ses"], "ses is not correct")
    assert_equal('login', record["op"], "op is not correct")
    assert_equal('1000', record["id"], "id is not correct")
    assert_equal('/usr/sb in/sshd', record["exe"], "exe is not correct")
    assert_equal('50.132.33.101', record["hostname"], "hostname is not correct")
    assert_equal('50.132.33.101', record["addr"], "addr is not correct")
    assert_equal('/dev/pts/1', record["terminal"], "terminal is not correct")
    assert_equal('success', record["res"], "res is not correct")
  end

  def test_parse_daemon_start
    time, record = @@auditlog_lib.parse('type=DAEMON_START msg=audit(1456379730.956:2187): auditd start, ver=2.4.2 format=raw kernel=4.2.0-22-generic auid=4294967295 pid=65305 subj=unconfined res=success')

    assert_equal(1456379730.956, time, "time is not correct")
    assert_equal('DAEMON_START', record["RecordType"], "RecordType is not correct")
    assert(record.has_key?("Computer"), "Computer is missing")
    assert_equal('1456379730.956:2187', record["AuditID"], "AuditID is not correct")
    assert_equal('2016-02-25T05:55:30.956Z', record["Timestamp"], "Timestamp is not correct")
    assert_equal('2187', record["SerialNumber"], "SerialNumber is not correct")
    assert_equal('auditd start,', record["AdditionalMessage"], "AdditionalMessage is not correct")
    assert_equal('2.4.2', record["ver"], "ver is not correct")
    assert_equal('raw', record["format"], "format is not correct")
    assert_equal('4.2.0-22-generic', record["kernel"], "kernel is not correct")
    assert_equal('4294967295', record["auid"], "auid is not correct")
    assert_equal('unset', record["audit_user"], "audit_user is not correct")
    assert_equal('65305', record["pid"], "pid is not correct")
    assert_equal('unconfined', record["subj"], "subj is not correct")
    assert_equal('success', record["res"], "res is not correct")
  end

  def test_parse_invalid_log
    assert_nothing_raised(RuntimeError, "No exception is expected") do
      time, record = @@auditlog_lib.parse('type=DAEMON_START msg=audit(1456379730.956:2187): auditd start, ver=2.4.2 format=raw kernel=4.2.0-22-generic auid=abc pid=xyz subj=unconfined res=success')

      assert_equal(1456379730.956, time, "time is not correct")
      assert_equal('root', record['audit_user'], 'audit_user should be the default value')
    end
  end
end

