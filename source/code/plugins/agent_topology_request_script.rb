require 'optparse'
require 'gyoku'
require 'rexml/document'

require_relative 'agent_common'

class AgentTopologyRequestOperatingSystemTelemetry < StrongTypedClass
  strongtyped_accessor :PercentUserTime, Integer
  strongtyped_accessor :PercentPrivilegedTime, Integer
  strongtyped_accessor :UsedMemory, Integer
  strongtyped_accessor :PercentUsedMemory, Integer
end

class AgentTopologyRequestOperatingSystem < StrongTypedClass
  strongtyped_accessor :Name, String
  strongtyped_accessor :Manufacturer, String
  strongtyped_arch     :ProcessorArchitecture
  strongtyped_accessor :Version, String
  strongtyped_accessor :InContainer, String
  strongtyped_accessor :InContainerVersion, String
  strongtyped_accessor :IsAKSEnvironment, String
  strongtyped_accessor :K8SVersion, String
  strongtyped_accessor :Telemetry, AgentTopologyRequestOperatingSystemTelemetry
end

class AgentTopologyRequest < StrongTypedClass

  strongtyped_accessor :FullyQualfiedDomainName, String
  strongtyped_accessor :EntityTypeId, String
  strongtyped_accessor :AuthenticationCertificate, String
  strongtyped_accessor :OperatingSystem, AgentTopologyRequestOperatingSystem

  def get_telemetry_data(os_info, conf_omsadmin, pid_file)
    os = AgentTopologyRequestOperatingSystem.new
    telemetry = AgentTopologyRequestOperatingSystemTelemetry.new

    if !File.exist?(os_info) && !File.readable?(os_info)
      raise ArgumentError, " Unable to read file #{os_info}; telemetry information will not be sent to server"
    end

    if File.exist?('/var/opt/microsoft/docker-cimprov/state/containerhostname')
      os.InContainer = "True"
      containerimagetagfile = '/var/opt/microsoft/docker-cimprov/state/omscontainertag'
      if File.exist?(containerimagetagfile) && File.readable?(containerimagetagfile)
        os.InContainerVersion = File.read(containerimagetagfile)
      end
      if !ENV['AKS_RESOURCE_ID'].nil?
        os.IsAKSEnvironment = "True"
      end
      k8sversionfile = "/var/opt/microsoft/docker-cimprov/state/kubeletversion"
      if File.exist?(k8sversionfile) && File.readable?(k8sversionfile) 
        os.K8SVersion = File.read(k8sversionfile)
      end
    else
      os.InContainer = "False"
    end

    # Get process stats from omsagent for telemetry
    if ENV['TEST_WORKSPACE_ID'].nil? && ENV['TEST_SHARED_KEY'].nil? && File.exist?(conf_omsadmin)
      process_stats = ""
      # If there is no PID file, the omsagent process has not started, so no telemetry
      if File.exist?(pid_file) and File.readable?(pid_file)
        pid = File.read(pid_file)
        process_stats = `/opt/omi/bin/omicli wql root/scx \"SELECT PercentUserTime, PercentPrivilegedTime, UsedMemory, PercentUsedMemory FROM SCX_UnixProcessStatisticalInformation where Handle like '#{pid}'\" | grep =`
      end

      process_stats.each_line do |line|
        telemetry.PercentUserTime = line.sub("PercentUserTime=","").strip.to_i if line =~ /PercentUserTime/
        telemetry.PercentPrivilegedTime = line.sub("PercentPrivilegedTime=", "").strip.to_i if  line =~ /PercentPrivilegedTime/
        telemetry.UsedMemory = line.sub("UsedMemory=", "").strip.to_i if line =~ / UsedMemory/
        telemetry.PercentUsedMemory = line.sub("PercentUsedMemory=", "").strip.to_i if line =~ /PercentUsedMemory/
      end
    end

       # Get OS info from scx-release
    File.open(os_info).each_line do |line|
      os.Name = line.sub("OSName=","").strip if line =~ /OSName/
      os.Manufacturer = line.sub("OSManufacturer=","").strip if line =~ /OSManufacturer/
      os.Version = line.sub("OSVersion=","").strip if line =~ /OSVersion/
    end

    self.OperatingSystem = os
    os.Telemetry = telemetry
    os.ProcessorArchitecture = "x64"

    # If OperatingSystem is sent in the topology request with nil OS Name, Manufacturer or Version, we get HTTP 403 error
    if !os.Name || !os.Manufacturer || !os.Version
      self.OperatingSystem = nil
    end
  end
end

def obj_to_hash(obj)
  hash = {}
  obj.instance_variables.each { |var|
    val = obj.instance_variable_get(var)
    next if val.nil?
    if val.is_a?(AgentTopologyRequestOperatingSystemTelemetry) 
      # Put properties of Telemetry class into :attributes["Telemetry"] 
      # so that Gyoku can convert these to attributes for <Telemetry></Telemetry> 
      telemetry_hash = {"Telemetry" => "", :attributes! => {"Telemetry" => obj_to_hash(val)} }
      hash.update(telemetry_hash)
    elsif val.is_a? StrongTypedClass
      hash[var.to_s.delete("@")] = obj_to_hash(val)
    else
      hash[var.to_s.delete("@")] = val
    end
  }
  return hash
end

def evaluate_fqdn()
  hostname = `hostname`
  domainname = `hostname -d 2> /dev/null`

  if !domainname.nil? and !domainname.empty?
    return "#{hostname}.#{domainname}"
  end
  return hostname
end

class AgentTopologyRequestHandler < StrongTypedClass
  def handle_request(os_info, conf_omsadmin, entity_type_id, auth_cert, pid_file, telemetry)
    topology_request = AgentTopologyRequest.new
    topology_request.FullyQualfiedDomainName = evaluate_fqdn()
    topology_request.EntityTypeId = entity_type_id
    topology_request.AuthenticationCertificate = auth_cert

    if telemetry
      topology_request.get_telemetry_data(os_info, conf_omsadmin, pid_file)
    end

    body_heartbeat = "<?xml version=\"1.0\"?>\n"
    body_heartbeat.concat(Gyoku.xml({ "AgentTopologyRequest" => {:content! => obj_to_hash(topology_request), \
:'@xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance", :'@xmlns:xsd' => "http://www.w3.org/2001/XMLSchema", \
:@xmlns => "http://schemas.microsoft.com/WorkloadMonitoring/HealthServiceProtocol/2014/09/"}}))

    return body_heartbeat
  end
end

# Returns true if the provided XML string has Operating System Telemetry within it
def xml_contains_telemetry(xmlstring)
  if xmlstring.nil? or xmlstring.empty?
    return false
  end

  doc = REXML::Document.new(xmlstring)
  if !doc.root.nil? and doc.root.elements.respond_to? :each
    doc.root.elements.each do |root_elem|
      if root_elem.name == "OperatingSystem" and root_elem.elements.respond_to? :each
        root_elem.elements.each do |op_sys_elem|
          if op_sys_elem.name == "Telemetry" and !op_sys_elem.attributes.empty?
            return true
          end
        end
      end
    end
  end

  return false
end

if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.on("-t", "--[no-]telemetry") do |t|
      options[:telemetry] = t 
    end
  end.parse!

  topology_request_xml = AgentTopologyRequestHandler.new.handle_request(ARGV[1], ARGV[2],
      ARGV[3], ARGV[4], ARGV[5], options[:telemetry])

  path = ARGV[0]
  File.open(path, 'a') do |f|
    f << topology_request_xml
  end
end
