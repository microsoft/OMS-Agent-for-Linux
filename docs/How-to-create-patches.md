## How to create a patch

Let suppose we need to patch in_syslog plugin in fluentd project:
* Create a copy of in_syslog.rb and name it in_syslog.rb.new
* Add the required changes to in_syslog.rb.new
* Navigate to /omsagent/build/ folder
* Run the diff cmd:
```
diff -Naur ../source/ext/fluentd/lib/fluent/plugin/in_syslog.rb ../source/ext/fluentd/lib/fluent/plugin/in_syslog.rb.new > ../source/ext/patches/fluentd/in_syslog.patch
```
* Add the following line to build/configure file:
```
apply_patch ${base_dir}/source/ext/patches/fluentd/in_syslog.patch ${base_dir}/source/ext/fluentd/lib/fluent/plugin/in_syslog.rb
```
* Run "./configure --enable-ulinux" and make sure the changes are applied.
* Run make && make unittest

