require "rexml/document"
require "cgi"
require 'digest'
require 'json'
require 'date'
require 'time'

require_relative 'antimalwarecommon'

class McAfee

	def initialize(log)
		@log = log
	end

	def self.detect()
		begin
			if !File.file?('/opt/isec/ens/threatprevention/bin/isecav')
				return false
			end			
			detectioncmd = `/opt/isec/ens/threatprevention/bin/isecav --version 2>&1`.lines.map(&:chomp)

			if !$?.success? || detectioncmd.nil? || detectioncmd.empty?
				puts "Fail to execute mcafee version cmd, mcafee is not detected on the machine"
				return false
			else
				mcafeeName = detectioncmd[0]
				mcafeeVersion = detectioncmd[1].split(" : ")[1]
				if mcafeeName != "McAfee Endpoint Security for Linux Threat Prevention"
					puts "Tool name is not McAfee Endpoint Security for Linux Threat Prevention: " + mcafeeName
					return false
				elsif mcafeeVersion.split(".")[0].to_i  < 10
					puts "Mcafee version is below 10, OMS only support version 10+: " + mcafeeVersion
					return false
				end
			end
			return true
		rescue => e
			puts "Getting exception when trying to detect mcafee: " + e.message + " " + e.backtrace.inspect			
			return false			
		end
	end

	def self.getprotectionstatus()
		
		ret = {}
		
		mcafeeName = "McAfee Endpoint Security for Linux Threat Prevention"
		mcafeeVersion = "NA"
		datVersion = "NA"
		datTime = "NA"
		engineVersion = "NA"

		quickscan = "NA"
		fullscan = "NA"
		datengupdate = "NA"

		onaccessscan = "NA"
		gti = "NA"
		accessprotection = "NA"

		error = ""

		($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::UnknownProtectionCode
		($ThreatStatusRank, $ThreatStatus) = AntimalwareCommon::UnknownThreatCode

		begin
			detectioncmd = `/opt/isec/ens/threatprevention/bin/isecav --version 2>&1`.lines.map(&:chomp)
			if !$?.success? || detectioncmd.nil? || detectioncmd.empty?
				puts "Fail to get mcafee version info"
				error += "Fail to get mcafee version info; "
			else 
				mcafeeVersion = detectioncmd[1].split(" : ")[1]
				datVersion = detectioncmd[3].split(" : ")[1]
				datTime = detectioncmd[4].split(" : ")[1]
				engineVersion = detectioncmd[5].split(" : ")[1]
			end

			#puts mcafeeName
			#puts mcafeeVersion
			#puts datVersion
			#puts datTime
			#puts engineVersion

			taskcmd = `/opt/isec/ens/threatprevention/bin/isecav --listtask 2>&1`.lines.map(&:chomp)

			if !$?.success? || taskcmd.nil? || taskcmd.empty?
				puts "fail to run listtask cmd"
				error += "fail to run listtask cmd; "
			else
				$i = 3
				$len = taskcmd.length-1

				while $i < $len  do
					if taskcmd[$i].include? "quick scan"
						if taskcmd[$i].include? "Not Applicable"
							quickscan = "NA"
						else		
							quickscanarray = taskcmd[$i].split(" ")
							$l = quickscanarray.length
							quickscan = quickscanarray[$l-4] + " " + quickscanarray[$l-3] + " UTC"
						end
					elsif taskcmd[$i].include? "full scan"
						if taskcmd[$i].include? "Not Applicable"
							fullscan = "NA"
						else		
							fullscanarray = taskcmd[$i].split(" ")
							$l = fullscanarray.length
							fullscan = fullscanarray[$l-4] + " " + fullscanarray[$l-3] + " UTC"
						end
					elsif taskcmd[$i].include? "DAT and Engine Update"
						if taskcmd[$i].include? "Not Applicable"
							datengupdate = "NA"
						else		
							datengupdatearray = taskcmd[$i].split(" ")
							$l = datengupdatearray.length
							datengupdate = datengupdatearray[$l-4] + " " + datengupdatearray[$l-3] + " UTC"
						end
					end
					$i +=1
				end  		
			end

			#puts quickscan
			#puts fullscan
			#puts datengupdate
	
			oascmd = `/opt/isec/ens/threatprevention/bin/isecav --getoasconfig --summary 2>&1`.lines.map(&:chomp)
			if !$?.success? || oascmd.nil? || oascmd.empty?
				puts "fail to run getoasconfig cmd"
				error += "fail to run getoasconfig cmd; "
			else
				if (oascmd[0].include? "On-Access Scan")
					onaccessscan = oascmd[0].split(": ")[1].strip
				end
				if (oascmd[3].include? "GTI")
					gti = oascmd[3].split(": ")[1].strip
				end
			end

			#puts onaccessscan
			#puts gti

			apcmd = `/opt/isec/ens/threatprevention/bin/isecav --getapstatus 2>&1`.lines.map(&:chomp)
			if !$?.success? || apcmd.nil? || apcmd.empty?
				puts "fail to run getapstatus cmd"
				error += "fail to run getapstatus cmd; "
			else
				if (apcmd[0].include? "Access Protection")
					accessprotection = apcmd[0].split(": ")[1].strip
				end
			end
			#puts accessprotection
		
			scandate = "Not Found"
			protectionStatusDetails = ""
			protectionStatusDetailsString = ""
			protectionStatusDetailsArray = []
			fullscanoutofdate = false
			quickscanoutofdate = false

			if (datTime == "NA" && datengupdate == "NA" )
				($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::NotReportingProtectionCode
				protectionStatusDetailsArray.push("DAT and Engine update not found")
			elsif (datTime == "NA" || (Time.parse(datTime).utc < (Time.now - 7*24*3600).utc)) && 
		   		(datengupdate == "NA" || (Time.strptime(datengupdate, "%d/%m/%y %H:%M:%S %Z") < (Time.now - 7*24*3600).utc))
		   		($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::SignaturesOutOfDateProtectionCode
		   		protectionStatusDetailsArray.push("DAT and Engine update are out of 7 days")
			end

			if (!fullscan.nil? && !fullscan.empty? && fullscan != "NA")
				scandate = fullscan
				if (Time.strptime(fullscan, "%d/%m/%y %H:%M:%S %Z").utc < (Time.now - 7*24*3600).utc)
					fullscanoutofdate = true
				end
			end

			if (!quickscan.nil? && !quickscan.empty? && quickscan != "NA")
				if (Time.strptime(quickscan, "%d/%m/%y %H:%M:%S %Z").utc < (Time.now - 7*24*3600).utc)
					quickscanoutofdate = true
				end
				if ((fullscanoutofdate && !quickscanoutofdate) || scandate == "Not Found")
					scandate = quickscan
				end			
			else
				($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::ActionRequiredProtectionCode
				protectionStatusDetailsArray.push("Full Scan and quick Scan are Not Applicable, please run an active scan")
			end

			if (fullscanoutofdate && quickscanoutofdate) ||
				(fullscanoutofdate && (quickscan.nil? || quickscan.empty? || quickscan == "NA")) ||
				(quickscanoutofdate && (fullscan.nil? || fullscan.empty? || fullscan == "NA"))
				($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::ActionRequiredProtectionCode
				protectionStatusDetailsArray.push("Both quick scan and full scan are out of 7 days, please run an active scan")
			end

			if (onaccessscan == "NA")
				($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::NotReportingProtectionCode
				protectionStatusDetailsArray.push("On access scan status not found: " + onaccessscan)
			elsif (!onaccessscan.downcase.include? "enabled")
				($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::NoRealTimeProtectionProtectionCode
				protectionStatusDetailsArray.push("On access scan is not enabled: " + onaccessscan)
			else
				protectionStatusDetailsString += "On access scan status: " + onaccessscan + ". "
			end

			if (gti != "NA") 
				protectionStatusDetailsString += "GIT status: " + gti + ". "
			end

			if (accessprotection != "NA") 
				protectionStatusDetailsString += "Access Protection status: " + accessprotection + ". "
			end

			if (datengupdate != "NA")
				protectionStatusDetailsString += "DAT and Engine update Time: " + datengupdate + ". "
			elsif(datTime != "NA")
				protectionStatusDetailsString += "DAT and Engine update Time: " + datTime + ". "
			end

			if protectionStatusDetailsArray.length == 0
				($ProtectionRank, $ProtectionStatus) = AntimalwareCommon::RealTimeProtectionCode
				protectionStatusDetailsString += "McAfee is running healthy."
				protectionStatusDetails = protectionStatusDetailsString
			else
				protectionStatusDetails = protectionStatusDetailsArray.join('; ')
			end
		rescue => e
			error += "Getting exception when trying to detect mcafee: " + e.message + " " + e.backtrace.inspect
			ret["Error"] = error					
		end
		ret["ProtectionRank"] = $ProtectionRank
    	ret["ProtectionStatus"] = $ProtectionStatus
    	ret["ProtectionStatusDetails"] = protectionStatusDetails
    	ret["DetectionId"] = SecureRandom.uuid
    	ret["Threat"] = ""
    	ret["ThreatStatusRank"] = $ThreatStatusRank
    	ret["ThreatStatus"] = $ThreatStatus
		ret["ThreatStatusDetails"] = "Threat Status is currently not supported in Linux McAfee"
		ret["Signature"] = (datVersion.nil? || datVersion.empty? || datVersion == "NA")? "Signature version not found" : datVersion
    	ret["ScanDate"] = scandate
    	ret["DateCollected"] = DateTime.now.strftime("%d/%m/%Y %H:%M")
    	ret["ToolName"] = mcafeeName
		ret["AMProductVersion"] = (mcafeeVersion.nil? || mcafeeVersion.empty? || mcafeeVersion == "NA")? "McAfee version not found" : mcafeeVersion
		return ret
	end
end
#print `/opt/isec/ens/threatprevention/bin/isecav --listtask`

#print `/opt/isec/ens/threatprevention/bin/isecav --getoasconfig --summary`

#print `/opt/isec/ens/threatprevention/bin/isecav --getapstatus`