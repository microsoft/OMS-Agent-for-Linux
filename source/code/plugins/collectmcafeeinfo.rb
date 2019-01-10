require "rexml/document"
require "cgi"
require 'digest'
require 'json'
require 'date'
require 'time'
require 'logger'
require_relative 'antimalwarecommon'

class McAfee

	def self.detect()	
		begin
			if !File.file?('/opt/isec/ens/threatprevention/bin/isecav')
				return false
			end			
			detectioncmd = `/opt/isec/ens/threatprevention/bin/isecav --version 2>&1`.lines.map(&:chomp)

			if !$?.success? || detectioncmd.nil? || detectioncmd.empty?				
				return false
			else
				mcafeeName = detectioncmd[0]
				mcafeeVersion = detectioncmd[1].split(" : ")[1]
				if mcafeeName != "McAfee Endpoint Security for Linux Threat Prevention"					
					return false
				elsif mcafeeVersion.split(".")[0].to_i  < 10					
					return false
				end
			end			
			return true
		rescue => e					
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

		scandate = ""
		protectionStatusDetails = ""
		protectionStatusDetailsString = ""
		protectionStatusDetailsArray = []
		fullscanoutofdate = false
		quickscanoutofdate = false

		error = ""

		($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::UnknownProtectionCode
		($ThreatStatusRank, $ThreatStatus) = AntimalwareCommon::UnknownThreatCode

		begin
			detectioncmd = `/opt/isec/ens/threatprevention/bin/isecav --version 2>&1`.lines.map(&:chomp)
			if !$?.success? || detectioncmd.nil? || detectioncmd.empty?			
				error += "Fail to get mcafee version info; "
			else 
				mcafeeVersion = detectioncmd[1].split(" : ")[1]
				datVersion = detectioncmd[3].split(" : ")[1]
				datTime = detectioncmd[4].split(" : ")[1]
				engineVersion = detectioncmd[5].split(" : ")[1]
			end

			taskcmd = `LANG=en_US.UTF-8 /opt/isec/ens/threatprevention/bin/isecav --listtask 2>&1`.lines.map(&:chomp)

			if !$?.success? || taskcmd.nil? || taskcmd.empty?				
				error += "fail to run listtask cmd; "
			else
				$i = 3
				$len = taskcmd.length

				while $i < $len-1  do
					if taskcmd[$i].include? "quick scan"
						if taskcmd[$i].include? "Not Applicable"
							quickscan = "NA"
						else		
							quickscanarray = taskcmd[$i].split(" ")
							quickscanStatus = 'NA'
							quickscan, quickscanStatus = parseMcAfeeDateTime(quickscanarray)							
							if quickscan == "NA"
								protectionStatusDetailsArray.push("Fail to parse quickscan date: " + taskcmd[$i])
							end
							if quickscanStatus != 'NA'
								protectionStatusDetailsString += "Quick scan status: " + quickscanStatus + ". "
							end
						end
					elsif taskcmd[$i].include? "full scan"
						if taskcmd[$i].include? "Not Applicable"
							fullscan = "NA"
						else		
							fullscanarray = taskcmd[$i].split(" ")
							fullscanStatus = 'NA'
							fullscan, fullscanStatus = parseMcAfeeDateTime(fullscanarray)						
							if fullscan == "NA"
								protectionStatusDetailsArray.push("Fail to parse fullscan date: " + taskcmd[$i])
							end
							if fullscanStatus != 'NA'
								protectionStatusDetailsString += "Full scan status: " + fullscanStatus + ". "
							end
						end
					elsif taskcmd[$i].include? "DAT and Engine Update"
						if taskcmd[$i].include? "Not Applicable"
							datengupdate = "NA"
						else		
							datengupdatearray = taskcmd[$i].split(" ")
							datengupdateStatus = 'NA'							
							datengupdate, datengupdateStatus = parseMcAfeeDateTime(datengupdatearray)
							if datengupdate == "NA"
								protectionStatusDetailsArray.push("Fail to parse DAT Engine update date: " + taskcmd[$i])
							end
							if datengupdateStatus != 'NA'
								protectionStatusDetailsString += "DAT Engine update status: " + datengupdateStatus + ". "
							end
						end
					end
					$i +=1
				end  		
			end

			oascmd = `/opt/isec/ens/threatprevention/bin/isecav --getoasconfig --summary 2>&1`.lines.map(&:chomp)
			if !$?.success? || oascmd.nil? || oascmd.empty?			
				error += "fail to run getoasconfig cmd; "
			else
				if (oascmd[0].include? "On-Access Scan")
					onaccessscan = oascmd[0].split(": ")[1].strip
				end
				if (oascmd[3].include? "GTI")
					gti = oascmd[3].split(": ")[1].strip
				end
			end

			apcmd = `/opt/isec/ens/threatprevention/bin/isecav --getapstatus 2>&1`.lines.map(&:chomp)
			if !$?.success? || apcmd.nil? || apcmd.empty?
				error += "fail to run getapstatus cmd; "
			else
				if (apcmd[0].include? "Access Protection")
					accessprotection = apcmd[0].split(": ")[1].strip
				end
			end

			if (datTime == "NA" && datengupdate == "NA" )
				($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::NotReportingProtectionCode
				protectionStatusDetailsArray.push("DAT and Engine update not found")
			elsif (datTime == "NA" || (Time.strptime(datTime, "%m-%d-%Y") < (Time.now - 7*24*3600))) &&
		   		(datengupdate == "NA" || datengupdate < (Time.now - 7*24*3600).utc)
		   		($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::SignaturesOutOfDateProtectionCode
		   		protectionStatusDetailsArray.push("DAT and Engine update are out of 7 days: " + datengupdate)
			end

			if (!fullscan.nil? && fullscan != "NA")
				scandate = fullscan
				if (fullscan < (Time.now - 7*24*3600).utc)
					fullscanoutofdate = true
				end
			end

			if (!quickscan.nil? && quickscan != "NA")
				if (quickscan < (Time.now - 7*24*3600).utc)
					quickscanoutofdate = true
				end
				if ((fullscanoutofdate && !quickscanoutofdate) || scandate == "")
					scandate = quickscan
				end			
			else
				($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::ActionRequiredProtectionCode
				protectionStatusDetailsArray.push("Full Scan and quick Scan are Not Applicable, please run an active scan")
			end

			if (fullscanoutofdate && quickscanoutofdate) ||
				(fullscanoutofdate && (quickscan.nil? || quickscan.empty? || quickscan == "NA")) ||
				(quickscanoutofdate && (fullscan.nil? || fullscan.empty? || fullscan == "NA"))
				($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::ActionRequiredProtectionCode
				protectionStatusDetailsArray.push("Both quick scan and full scan are out of 7 days, please run an active scan")
			end

			if (onaccessscan == "NA")
				($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::NotReportingProtectionCode
				protectionStatusDetailsArray.push("On access scan status not found: " + onaccessscan)
			elsif (!onaccessscan.downcase.include? "enabled")
				($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::NoRealTimeProtectionProtectionCode
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
				protectionStatusDetailsString += "DAT and Engine update Time: " + datengupdate.to_s + ". "
			elsif(datTime != "NA")
				protectionStatusDetailsString += "DAT and Engine update Time: " + datTime.to_s + ". "
			end

			if protectionStatusDetailsArray.length == 0
				($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::RealTimeProtectionCode
				protectionStatusDetailsString += "McAfee is running healthy."
				protectionStatusDetails = protectionStatusDetailsString
			else
				protectionStatusDetails = protectionStatusDetailsArray.join('; ')
			end
		rescue => e
			error += "Getting exception when trying to find mcafee health info: " + e.message + " " + e.backtrace.inspect
			ret["Error"] = error					
		end

		if(scandate != "")
			scanarray = scandate.to_s.split(" ")
			if (scanarray.length >= 3) 
				scandate = scanarray[0] + " " + scanarray[1]
			end
		end
		ret["ProtectionStatusRank"] = $ProtectionStatusRank
    	ret["ProtectionStatus"] = $ProtectionStatus
    	ret["ProtectionStatusDetails"] = protectionStatusDetails
    	ret["DetectionId"] = SecureRandom.uuid
    	ret["Threat"] = ""
    	ret["ThreatStatusRank"] = $ThreatStatusRank
    	ret["ThreatStatus"] = $ThreatStatus
		ret["ThreatStatusDetails"] = "Threat Status is currently not supported in Linux McAfee"
		ret["Signature"] = (datVersion.nil? || datVersion.empty? || datVersion == "NA")? "Signature version not found" : datVersion
    	ret["ScanDate"] = scandate
    	ret["DateCollected"] = DateTime.now.strftime("%m/%d/%Y %H:%M")
    	ret["Tool"] = mcafeeName
		ret["AMProductVersion"] = (mcafeeVersion.nil? || mcafeeVersion.empty? || mcafeeVersion == "NA")? "McAfee version not found" : mcafeeVersion
		return ret
	end

	def self.parseMcAfeeDateTime(datearray)		
		$l = datearray.length
		scandate = 'NA'
		scanstatus = 'NA'		
		if $l >= 4
			if(!datearray[$l-3].include? "AM") && (!datearray[$l-3].include? "PM")
				scandate = datearray[$l-4] + " " + datearray[$l-3] + " " + datearray[$l-2]						
				scandate = Time.strptime(scandate, '%d/%m/%y %H:%M:%S %Z')
			elsif $l >= 8
				scandate = datearray[$l-7] + " " + datearray[$l-6] + " " + datearray[$l-5] + " " + datearray[$l-4] + " " + datearray[$l-3] + " " + datearray[$l-2]				
				scandate = Time.strptime(scandate, '%d %b %Y %I:%M:%S %p %Z')
			end
			if $l >= 5 && (!datearray[4].include? "Not")
				scanstatus = datearray[4]
			end
			if $l >= 10 && (datearray[4].include? "task") && (!datearray[9].include? "Not")
				scanstatus = datearray[9]
			end
		end
		return scandate, scanstatus
	end
end