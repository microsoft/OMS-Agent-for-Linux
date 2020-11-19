# Linux Hardening using OMS Log Collector
We support some industry standard hardening (please see [Supported Hardening or Customization](#supported-hardening-or-customization) for more details). Other forms of hardening are officially unsupported, but we provide some [troubleshooting steps](#common-hardening-issues) to follow for customized hardening.

# Table of Contents
- [Supported Hardening or Customization](#supported-hardening-or-customization)
- [Common Hardening Issues](#common-hardening-issues)
- [Documentation](#documentation)

## Supported Hardening or Customization
### Hardening with FIPS
FIPS hardening is supported in OMS versions 1.13 and newer.

How to check if FIPS is enabled:
```
$> cat /proc/sys/crypto/fips_enabled
1
$> sysctl crypto.fips_enabled
crypto.fips_enabled = 1
```

### Hardening with Cylance Anti-Virus
Cylance Anti-Virus hardening is supported in OMS versions 1.12 and newer.

### Not Yet Supported Hardening
- SELinux
- Center for Internet Security (CIS)

## Common Hardening Issues
If you're using a customized hardening setup, and are having issues running the OMS Agent, try going through these common problems encountered with hardening.
### Directory Permissions
#### Issue
Several major folders in Linux need to have appropriate file permissions, otherwise the OMS Agent won't run properly. Specifically, we need the following:
| Directory | Permissions (numeric value) | Permissions (symbolic notation) |
| --- | --- | --- |
| `/var` | 755 | `drwxr-xr-x` |
| `/var/log` | 775 | `drwxrwxr-x` |
| `/etc` | 775 | `drwxrwxr-x` |
| `/opt` | 775 | `drwxrwxr-x` |
| `/tmp` | 775 | `drwxrwxr-x` |

#### How to Check
You can check what the permissions for these folders are by the following:
```
$> ls -l / | grep -E 'var|etc|opt|tmp'; ls -ld /var/log
drw-r--r--.  85 root root 8192 Nov 13 00:55 etc
dr--------.   6 root root   55 Nov 10 18:15 opt
dr-x--x---.   7 root root   93 Nov 18 03:13 tmp
dr-x--x--x.  20 root root  282 Nov 13 00:54 var
drwxr-----.  10 root root 4096 Nov 15 03:36 /var/log

```

#### How to Fix
If you find any of the above directories have too strict permissions, you can change the permissions by the following:
```
$> chmod 755 /var
$> chmod 775 /var/log
$> chmod 775 /etc
$> chmod 775 /tmp
```

### Hard Limitation to Thread Resources
#### Issue
It's possible to set a security limitation to limit the number of threads any process running as omsagent user (like omsagent, dsc, omi, npm, ...) to create a maximum which is too low for the agent to run successfully. The omsagent user needs to be able to run at least 200 threads in order to run successfully.

#### How to Check
You can see the number of threads omsagent is limited to by running:
```
$> cat /etc/security/limits.conf | grep omsagent
omsagent  hard  nproc  75
```
**Note:** If you don't see anything upon running the above command, it means that omsagent isn't being limited, and this isn't the problem.

It's also possible that this is the issue if you see the below log show up in omsagent.log:
```
2020-01-16 10:38:57 -0800 [error]: unexpected error error_class=ThreadError error=#<ThreadError: can't create Thread: Resource temporarily unavailable>
```

#### How to Fix
If you increase the number to 200, then that should solve the issue immediately. This can be done by opening up `/etc/security/limits.conf` in a text editor, and changing the number next to omsagent to 200.

You can check if it was successful by doing the following:
```
$> cat /etc/security/limits.conf | grep omsagent
omsagent  hard  nproc  200
```

### Existing Ruby from RVM
#### Issue
OMS Agent ships a specific version of Ruby. Installing a different version of Ruby from the RVM (Ruby Version Manager) may define global environment variables (e.g. `GEM_HOME`, `GEM_PATH`) that conflict with those used by the OMS-specific Ruby installation.

#### How to Check
You can check the version of Ruby that's running with the following commands:
```
$> ruby --version
ruby 2.2.2p95 (2015-04-13 revision 50295) [x86_64-linux]
$> which ruby
/usr/local/rvm/rubies/ruby-2.2.2/bin/ruby
```
The standard Ruby install should result in below:
```
$> which ruby
/usr/bin/ruby
```
If you see something unusual (like above), then it's possible that the wrong version of Ruby is installed.

You can double check which GEM that Ruby is using in OMS Agent by the following:
```
$> /opt/microsoft/omsagent/ruby/bin/gem environmen
RubyGems Environment:
  - RUBYGEMS VERSION: 3.0.3
  - RUBY VERSION: 2.6.3 (2019-04-16 patchlevel 62) [x86_64-linux]
  - INSTALLATION DIRECTORY: /usr/local/rvm/gems/ruby-2.2.2
  - USER INSTALLATION DIRECTORY: /root/.gem/ruby/2.6.0
  - RUBY EXECUTABLE: /opt/microsoft/omsagent/ruby/bin/ruby
  - GIT EXECUTABLE: /usr/bin/git
  - EXECUTABLE DIRECTORY: /usr/local/rvm/gems/ruby-2.2.2/bin
  - SPEC CACHE DIRECTORY: /root/.gem/specs
  - SYSTEM CONFIGURATION DIRECTORY: /opt/microsoft/omsagent/ruby/etc
  - RUBYGEMS PLATFORMS:
    - ruby
    - x86_64-linux
  - GEM PATHS:
     - /usr/local/rvm/gems/ruby-2.2.2
     - /usr/local/rvm/rubies/ruby-2.2.2/lib/ruby/gems/2.2.0
  - GEM CONFIGURATION:
     - :update_sources => true
     - :verbose => true
     - :backtrace => false
     - :bulk_threshold => 1000
  - REMOTE SOURCES:
     - https://rubygems.org/
  - SHELL PATH:
     - /usr/local/rvm/gems/ruby-2.2.2/bin
     - /usr/local/rvm/gems/ruby-2.2.2@global/bin
     - /usr/local/rvm/rubies/ruby-2.2.2/bin
     - /home/banban/jdk1.8.0_144/bin
     - /usr/local/sbin
     - /usr/local/bin
     - /sbin
     - /bin
     - /usr/sbin
     - /usr/bin
     - /usr/local/rvm/bin
     - /root/bin
```
Specifically, checking the `GEM PATHS` section should give an idea as to what paths are being used for Ruby. You can also check the individual paths with the following:
```
$> echo $GEM_HOME
/usr/local/rvm/gems/ruby-2.2.2
$> echo $GEM_PATH
/usr/local/rvm/gems/ruby-2.2.2:/usr/local/rvm/gems/ruby-2.2.2@global
```

#### How to Fix
An immediate fix would be just to remove RVM from the PATH environment:
```
$> mv /etc/profile.d/rvm.sh /etc/profile.d/rvm.sh.bak
```
And then re-login again.

A more long-term solution would involve removing RVM from the machine entirely. After removing RVM, you can test this quickly using this command:
```
$> /opt/microsoft/omsagent/ruby/bin/ruby -e "require 'gyoku'; puts 'Test done'"
Test done
```

### Custom OpenSSL Installation
#### Issue
It's possible to have a custom version of OpenSSL on the machine, which when set in the PATH, will cause Ruby (shipped by OMS) to fail while loading the openssl.so library.

#### How to Check
The logs in omsagent.log can have this error:
```
omsagent: /opt/microsoft/omsagent/ruby/lib/ruby/2.6.0/rubygems/core_ext/kernel_require.rb:54:in `require': libssl.so.1.1: cannot open shared object file: No such file or directory - /opt/microsoft/omsagent/ruby/lib/ruby/2.6.0/x86_64-linux/openssl.so (LoadError)
```

In addition, you can take a look at the OpenSSL libssl locations to see if they show anything unusual:
```
$> ldd /opt/microsoft/omsagent/ruby/lib/ruby/2.6.0/x86_64-linux/openssl.so
	linux-vdso.so.1 (0x00007fff5b141000)
	libssl.so.1.1 => /opt/app/softwares/openssl/lib/libssl.so.1.1 (0x00007f6fe039e000)
	libcrypto.so.1.1 => /opt/app/softwares/openssl/lib/libcrypto.so.1.1 (0x00007f6fdfed3000)
  libm.so.6 => /lib64/libm.so.6 (0x00007ff724024000)
	libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f6fdfcb4000)
	libc.so.6 => /lib64/libc.so.6 (0x00007f6fdf8c3000)
	libdl.so.2 => /lib64/libdl.so.2 (0x00007f6fdf6bf000)
	/lib64/ld-linux-x86-64.so.2 (0x00007f6fe08de000)
```
Specifically, the `libssl.so` and `libcrypto.so` locations should be pointing to the `/opt/omi/lib/` locations, unlike above, where they're pointing to `/opt/app/softwares/openssl/lib` locations. If the filepaths seem unusual, it's a high likelihood that the OpenSSL version is customized, which can cause issues.

You can also check the version of OpenSSL on the machine:
```
$> openssl version
OpenSSL 1.1.1d  10 Sep 2019
```
And see if it matches up with the version that was shipped with the specific distro being used.

#### How to Fix
Unfortunately, we don't support customized versions of OpenSSL at the moment. To get the OMS Agent working again, the best course of action would be to ensure the original OpenSSL version associated with the distro is installed.

## Documentation
You can find more information about our supported hardening scenarios and future plans by going to the [official Microsoft Docs page for the OMS Agent](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/agent-linux#supported-linux-hardening).
