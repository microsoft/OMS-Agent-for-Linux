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
		#logger = Logger.new('/opt/microsoft/omsagent/plugin/omsagent.log')
		#logger.info("Trying to find if mcafee running on the machine...")
		begin
			if !File.file?('/opt/isec/ens/threatprevention/bin/isecav')
				return false
			end			
			detectioncmd = `/opt/isec/ens/threatprevention/bin/isecav --version 2>&1`.lines.map(&:chomp)

			if !$?.success? || detectioncmd.nil? || detectioncmd.empty?
				#logger.info "Fail to execute mcafee version cmd, mcafee is not detected on the machine"
				return false
			else
				mcafeeName = detectioncmd[0]
				mcafeeVersion = detectioncmd[1].split(" : ")[1]
				if mcafeeName != "McAfee Endpoint Security for Linux Threat Prevention"
					#logger.info "Tool name is not McAfee Endpoint Security for Linux Threat Prevention: " + mcafeeName
					return false
				elsif mcafeeVersion.split(".")[0].to_i  < 10
					#loggerinfo "Mcafee version is below 10, OMS only support version 10+: " + mcafeeVersion
					return false
				end
			end
			#logger.info("McAfee is detected on the machine")
			return true
		rescue => e
			#logger.info "Getting exception when trying to detect mcafee: " + e.message + " " + e.backtrace.inspect			
			return false			
		end
	end

	def self.getprotectionstatus()
		#file = File.open('/opt/microsoft/omsagent/plugin/omsagent.log', File::WRONLY | File::APPEND)
		#logger = Logger.new(file)
		#logger.info "Collecting mcafee health info" 
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
				#logger.info "Fail to get mcafee version info"
				error += "Fail to get mcafee version info; "
			else 
				mcafeeVersion = detectioncmd[1].split(" : ")[1]
				datVersion = detectioncmd[3].split(" : ")[1]
				datTime = detectioncmd[4].split(" : ")[1]
				engineVersion = detectioncmd[5].split(" : ")[1]
			end

			taskcmd = `/opt/isec/ens/threatprevention/bin/isecav --listtask 2>&1`.lines.map(&:chomp)

			if !$?.success? || taskcmd.nil? || taskcmd.empty?
				#logger.info "fail to run listtask cmd"
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
							#|1   quick scan      ODS      Not Started   25/10/18 23:44:42 UTC      |
							if $l >= 4
								#25/10/18
								quickscandate = quickscanarray[$l-4].split("/")
								if quickscandate.length >= 3
									quickscan = quickscandate[1] + "/" + quickscandate[0] + "/20" + quickscandate[2] + " " + quickscanarray[$l-3]#+ " UTC"
									if $l >= 5
										quickscanStatus = quickscanarray[$l-5]
										if (quickscanStatus.include? "Stopped") || (quickscanStatus.include? "Aborted") || (quickscanStatus.include? "Completed") || (quickscanStatus.include? "Running")
											protectionStatusDetailsString += "Quick scan status: " + quickscanStatus + ". "
										end
									end
								else
									quickscan = "NA"
								end
							else
								quickscan = "NA"
								protectionStatusDetailsArray.push("Fail to parse quickscan date: " + taskcmd[$i])
							end
						end
					elsif taskcmd[$i].include? "full scan"
						if taskcmd[$i].include? "Not Applicable"
							fullscan = "NA"
						else		
							fullscanarray = taskcmd[$i].split(" ")
							$l = fullscanarray.length
							if $l >= 4
								#25/10/18
								fullscandate = fullscanarray[$l-4].split("/")
								if fullscandate.length >= 3
									fullscan = fullscandate[1] + "/" + fullscandate[0] + "/20" + fullscandate[2] + " " + fullscanarray[$l-3]#+ " UTC"
									if $l >= 5
										fullscanStatus = fullscanarray[$l-5]
										if (fullscanStatus.include? "Stopped") || (fullscanStatus.include? "Aborted") || (fullscanStatus.include? "Completed") || (fullscanStatus.include? "Running")
											protectionStatusDetailsString += "Full scan status: " + fullscanStatus + ". "
										end
									end
								else
									fullscan = "NA"
								end
							else
								fullscan = "NA"
								protectionStatusDetailsArray.push("Fail to parse fullscan date: " + taskcmd[$i])
							end
						end
					elsif taskcmd[$i].include? "DAT and Engine Update"
						if taskcmd[$i].include? "Not Applicable"
							datengupdate = "NA"
						else		
							datengupdatearray = taskcmd[$i].split(" ")
							$l = datengupdatearray.length
							if $l >= 4
								#25/10/18
								dateng = datengupdatearray[$l-4].split("/")
								if dateng.length >= 3
									datengupdate = dateng[1] + "/" + dateng[0] + "/20" + dateng[2] + " " + datengupdatearray[$l-3] + " UTC"
								else
									datengupdate = "NA"
								end
							else
								datengupdate = "NA"
								protectionStatusDetailsArray.push("Fail to parse DAT Engine update date: " + taskcmd[$i])
							end
						end
					end
					$i +=1
				end  		
			end

			oascmd = `/opt/isec/ens/threatprevention/bin/isecav --getoasconfig --summary 2>&1`.lines.map(&:chomp)
			if !$?.success? || oascmd.nil? || oascmd.empty?
				#logger.info "fail to run getoasconfig cmd"
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
				#logger.info "fail to run getapstatus cmd"
				error += "fail to run getapstatus cmd; "
			else
				if (apcmd[0].include? "Access Protection")
					accessprotection = apcmd[0].split(": ")[1].strip
				end
			end

			if (datTime == "NA" && datengupdate == "NA" )
				($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::NotReportingProtectionCode
				protectionStatusDetailsArray.push("DAT and Engine update not found")
			elsif (datTime == "NA" || (Time.parse(datTime).utc < (Time.now - 7*24*3600).utc)) && 
		   		(datengupdate == "NA" || (Time.strptime(datengupdate, "%m/%d/%Y %H:%M:%S %Z") < (Time.now - 7*24*3600).utc))
		   		($ProtectionStatusRank, $ProtectionStatus) = AntimalwareCommon::SignaturesOutOfDateProtectionCode
		   		protectionStatusDetailsArray.push("DAT and Engine update are out of 7 days: " + datengupdate)
			end

			if (!fullscan.nil? && !fullscan.empty? && fullscan != "NA")
				scandate = fullscan
				if (Time.strptime(fullscan, "%m/%d/%Y %H:%M:%S").utc < (Time.now - 7*24*3600).utc)
					fullscanoutofdate = true
				end
			end

			if (!quickscan.nil? && !quickscan.empty? && quickscan != "NA")
				if (Time.strptime(quickscan, "%m/%d/%Y %H:%M:%S").utc < (Time.now - 7*24*3600).utc)
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
				protectionStatusDetailsString += "DAT and Engine update Time: " + datengupdate + ". "
			elsif(datTime != "NA")
				protectionStatusDetailsString += "DAT and Engine update Time: " + datTime + ". "
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
end