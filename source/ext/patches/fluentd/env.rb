#
# Fluentd
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

module Fluent
  DEFAULT_CONFIG_PATH = ENV['FLUENT_CONF'] || '/etc/opt/microsoft/omsagent/conf/omsagent.conf'
  DEFAULT_PLUGIN_DIR = ENV['FLUENT_PLUGIN'] || '/opt/microsoft/omsagent/plugin'
  DEFAULT_SOCKET_PATH = ENV['FLUENT_SOCKET'] || '/var/opt/microsoft/omsagent/run/omsagent.sock'
  DEFAULT_OJ_OPTIONS = {bigdecimal_load: :float, mode: :compat, use_to_json: true}
  DEFAULT_LISTEN_PORT = 25224
  DEFAULT_FILE_PERMISSION = 0640
  DEFAULT_DIR_PERMISSION = 0755
end
