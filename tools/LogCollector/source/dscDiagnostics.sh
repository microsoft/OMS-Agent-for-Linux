#!/bin/bash

related_processes=(omiserver omiengine omiagent omsagent omicli OMSConsistencyInvoker)

if [[ -n $1 ]]; then
	output_path=$1
else
	output_path="dscLogCollector.$(date +%s).out"
fi
mkdir -p ./$output_path

log_file=./$output_path/dscdiag.log

date > ${log_file}

echo '=================================================' | tee -a ${log_file}
uname -a  | tee -a ${log_file}
echo '=================================================' | tee -a ${log_file}

for target_process in "${related_processes[@]}"
do
	:
	echo '=================================================' | tee -a ${log_file}
	echo "~ Investigating" $target_process | tee -a ${log_file}

	echo "~ Executing the following command:" | tee -a ${log_file}
	echo "ps axo user,pid,ppid,pcpu,pmem,vsz,rss,tty,stat,start_time,time,comm | grep " $target_process " | grep -v grep" | tee -a ${log_file}
	echo '-------------------------------------------------' | tee -a ${log_file}
	ps axo user,pid,ppid,pcpu,pmem,vsz,rss,tty,stat,start_time,time,comm | grep $target_process | grep -v grep | tee -a ${log_file}
	echo '-------------------------------------------------' | tee -a ${log_file}

	target_process_pid_array=$(ps axo pid,comm | awk '{$1=$1};1' | grep $target_process | grep -v grep | cut -d' ' -f1)

	if [ -z "${target_process_pid_array}" ]; then
		echo "target_process_pid for " $target_process " is unset or set to an empty string" | tee -a ${log_file}
		continue
	fi
	
	for target_process_pid in $target_process_pid_array
	do
		:
		echo '+++++++++++++++++++++++++++++++++++++++++++++++++' | tee -a ${log_file}
		echo "~ Executing the following command:" | tee -a ${log_file}
		echo "sudo lsof -p " $target_process_pid | tee -a ${log_file}
		echo '-------------------------------------------------' | tee -a ${log_file}
		sudo lsof -p $target_process_pid | tee -a ${log_file}
		echo '-------------------------------------------------' | tee -a ${log_file}

		echo "~ Executing the following command:" | tee -a ${log_file}
		echo "pstree -pau " $target_process_pid | tee -a ${log_file}
		echo '-------------------------------------------------' | tee -a ${log_file}
		pstree -pau $target_process_pid | tee -a ${log_file}
		echo '-------------------------------------------------' | tee -a ${log_file}

		echo "~ Executing the following command:" | tee -a ${log_file}
		echo "sudo pmap -x " $target_process_pid | tee -a ${log_file}
		echo '-------------------------------------------------' | tee -a ${log_file}
		sudo pmap -x $target_process_pid | tee -a ${log_file}
		echo '-------------------------------------------------' | tee -a ${log_file}

		echo "~ Capturing process info for :" $target_process $target_process_pid | tee -a ${log_file}
		echo '-------------------------------------------------' | tee -a ${log_file}
		folder_name=$target_process.$target_process_pid
		mkdir -p ./$output_path/$folder_name
		sudo cp /proc/$target_process_pid/cmdline ./$output_path/$folder_name/
		sudo cp /proc/$target_process_pid/maps ./$output_path/$folder_name/
		sudo cp /proc/$target_process_pid/smaps ./$output_path/$folder_name/
		sudo cp /proc/$target_process_pid/stat ./$output_path/$folder_name/
		sudo cp /proc/$target_process_pid/status ./$output_path/$folder_name/
		echo '-------------------------------------------------' | tee -a ${log_file}

	done

	echo '=================================================' | tee -a ${log_file}
done

tar -cvf $output_path.tar.gz ./$output_path
