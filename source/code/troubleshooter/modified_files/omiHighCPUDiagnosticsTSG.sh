#!/bin/bash
#set -x
declare -a ppuc
declare -a pt
cpu_threshold=20
rescan_interval_sec=5
default_runtime_min=1440
runtime_min=$default_runtime_min
count=`expr $default_runtime_min / $rescan_interval_sec`
script_location="./files"  # TODO: change with permanent place
omiagent_trace_path="$script_location/omiagent_trace"
omiagent_trace_bak_path="$script_location/omiagent_trace.bak"
omi_log_path="/var/opt/omi/log"
scx_log_path="/var/opt/microsoft/scx/log"
omi_log_file="${omi_log_path}/omiserver.log"
omiagent_log_file="${omi_log_path}/omiagent.root.root.log"
scx_log_file="${scx_log_path}/scx.log"
incl_tsg_file=0
tsg_omiagent_trace_path="$script_location/tsg_omiagent_trace"

if [ "$1" = "--help" ]; then
    echo "This scipt runs for $default_runtime_min minutes, and collect info about omiagent process with high cpu utilization ( > $cpu_threshold% )."
    echo "When CPU utilization is high it takes the stack trace snapshot for the omiagent for 10 times in interval of ${rescan_interval_sec} sec."
    echo "Then rescan the system in interval of ${rescan_interval_sec} sec."
    echo "It also collects the diff of scx and omi logs in every ${rescan_interval_sec} sec"
    echo "  Option            Description"
    echo "--cpu-threshold     set cpu threashold, default $cpu_threshold% (decimal only)"
    echo "--runtime-in-min    set run time in minutes, default $default_runtime_min min <=> `expr $default_runtime_min / 60` hours"
    echo "--trace-enable      set verbose logging for omi and scx with option trace-enable"
    echo "--trace-disable     disable verbose logging for omi and scx"
    exit 0;
elif [ "$1" = "--trace-enable" ]; then
    echo "Increasing log level; existing settings will be clobbered."
    /opt/microsoft/scx/bin/tools/scxadmin -log-set all intermediate
    sed -i 's/#*loglevel/loglevel/' /etc/opt/omi/conf/omiserver.conf
    sed -i 's/WARNING/DEBUG/' /etc/opt/omi/conf/omiserver.conf
    /opt/microsoft/scx/bin/tools/scxadmin -restart
    exit 0
elif [ "$1" = "--trace-disable" ]; then
    echo "Restoring default log levels"
    /opt/microsoft/scx/bin/tools/scxadmin -log-set all errors
    sed -i 's/loglevel/#loglevel/' /etc/opt/omi/conf/omiserver.conf
    /opt/microsoft/scx/bin/tools/scxadmin -restart
    exit 0
fi

# optional arguments
if [ "$1" = "--runtime-in-min" ]; then
    runtime_min=$2
    if [ $runtime_min -gt 0 ]; then
        let "count = ( $runtime_min * 60 )/ $rescan_interval_sec"
        shift 2
    else
        echo "runtime value of '$runtime_min' is invalid, should be greater than or equal to 1" >& 2; exit 1;
    fi
fi
# optional arguments
if [ "$1" = "--cpu-threshold" ]; then
    threshold=$2
    if [ $threshold -gt 0 ]; then
        cpu_threshold=$threshold
        shift 2
    else
        echo "threshold value of '$threshold' is invalid, should be greater than or equal to 1" >& 2; exit 1;
    fi
fi

# optional arguments
if [ "$1" = "--tsg-file" ]; then
    incl_tsg_file=1
    shift 1
fi

which -a gdb  &> /dev/null
if [ $? != 0 ]; then
    echo "gdb program was not found, please install gdb to proceed." >& 2; exit 1;
fi

if [ -e $omiagent_trace_path ]; then
    rm -f $omiagent_trace_path
fi

if [ $incl_tsg_file -eq 1 ] && [ -e $tsg_omiagent_trace_path ]; then
    rm -f $tsg_omiagent_trace_path
fi

omiserver_log_line=`wc -l $omi_log_file |awk '{print $1}'`
scx_log_line=`wc -l $scx_log_file |awk '{print $1}'`
omiagent_log_line=`wc -l $omiagent_log_file |awk '{print $1}'`

sigint()
{
    echo "Removing Temporary Log Files"
    rm -f omiserver1.log scx1.log omiagent.root.root.1.log
    echo "$omiagent_trace_path log file back up taken"
    mv $omiagent_trace_path $omiagent_trace_bak_path
    exit 0
}

trap 'sigint' INT
trap 'sigint' QUIT

dump_scx_omi_log_diff_split()
{
    echo -e "\n\n" >>$omiagent_trace_path
    echo "OMI Server log Diff in last 10 min">>$omiagent_trace_path
    echo "------------------------------------------------">>$omiagent_trace_path
    omiserver_log_line1=`wc -l $omi_log_file`
    if [ $omiserver_log_line1 -ne $omiserver_log_line ]; then
        split -l $omiserver_log_line $omi_log_file omiserversnap
        find $(omi_log_path) -maxdepth 1 -iname 'omiserversnap*' -not -name 'omiserversnapaa' -exec cat {} +>>$omiagent_trace_path
        rm -f $(omi_log_path)/omiserversnap*
        omiserver_log_line=$omiserver_log_line1
    fi

    echo -e "\n\n" >>$omiagent_trace_path
    echo "OMIagent  log Diff in last 10 min">>$omiagent_trace_path
    echo "------------------------------------------------">>$omiagent_trace_path
    scx_log_line1=`wc -l $scx_log_file`
    if [ $scx_log_line1 -ne $scx_log_line ]; then
        split -l $scx_log_line $scx_log_file scxsnap
        find $scx_log_path -maxdepth 1 -iname 'scxsnap*' -not -name 'scxsnapaa' -exec cat {} +>>$omiagent_trace_path
        rm -f $(scx_log_path)/scxsnap*
        scx_log_line=$scx_log_line1
    fi

    echo -e "\n\n" >>$omiagent_trace_path
    echo "SCX log Diff in last 10 min">>$omiagent_trace_path
    echo "------------------------------------------------">>$omiagent_trace_path
    omiagent_log_line1=`wc -l $omiagent_log_file`
    if [ $omiagent_log_line1 -ne $omiagent_log_line ]; then
        split -l $omiagent_log_line $omiagent_log_file omiserversnap
        find $omi_log_path -maxdepth 1 -iname 'omiagentsnap*' -not -name 'omiagentsnapaa' -exec cat {} +>>$omiagent_trace_path
        rm -f $(omi_log_path)/omiagentsnap*
        omiagent_log_line=$omiagent_log_line1
    fi
}

dump_scx_omi_log_diff_tail()
{
    echo -e "\n\n" >>$omiagent_trace_path
    echo "OMI Server log Diff in last 10 min">>$omiagent_trace_path
    echo "------------------------------------------------">>$omiagent_trace_path
    omiserver_log_line1=`wc -l $omi_log_file |awk '{print $1}'`
    if [ $omiserver_log_line1 -ne $omiserver_log_line ]; then
        lineNo=`expr $omiserver_log_line1 - $omiserver_log_line`
        tail -n $lineNo $omi_log_file >>$omiagent_trace_path
        omiserver_log_line=$omiserver_log_line1
    fi

    echo -e "\n\n" >>$omiagent_trace_path
    echo "OMIagent  log Diff in last 10 min">>$omiagent_trace_path
    echo "------------------------------------------------">>$omiagent_trace_path
    scx_log_line1=`wc -l $scx_log_file |awk '{print $1}'`
    if [ $scx_log_line1 -ne $scx_log_line ]; then
        lineNo=`expr $scx_log_line1 - $scx_log_line`
        tail -n $lineNo $scx_log_file>>$omiagent_trace_path
        scx_log_line=$scx_log_line1
    fi


    echo -e "\n\n" >>$omiagent_trace_path
    echo "SCX log Diff in last 10 min">>$omiagent_trace_path
    echo "------------------------------------------------">>$omiagent_trace_path
    omiagent_log_line1=`wc -l $omiagent_log_file |awk '{print $1}'`
    if [ $omiagent_log_line1 -ne $omiagent_log_line ]; then
        lineNo=`expr $omiagent_log_line1 - $omiagent_log_line`
        tail -n $lineNo $omiagent_log_file>>$omiagent_trace_path
        omiagent_log_line=$omiagent_log_line1
    fi
}

echo "Traces will be saved to this file: $omiagent_trace_path"
if [ $incl_tsg_file -eq 1 ]; then
    echo "Troubleshooter-friendly traces will be saved to this file: $tsg_omiagent_trace_path"
fi
echo "Running for $runtime_min min, samples=$count, cpu_threshold=$cpu_threshold%"

while [ $count -gt 0 ]
do
	date>>$omiagent_trace_path
    ppuc=(`top -b -n1|grep omiagent|tee -a $omiagent_trace_path|awk '{print $9;print $1}'`)

	index=0
	index1=0;
	while [ $index -lt ${#ppuc[@]} ]
	do
 		if [ $(echo "${ppuc[$index]} > $cpu_threshold"|bc) -eq 1 ]; then
            ind=`expr $index + 1`
            echo -e "\n\n" >>$omiagent_trace_path
            echo "Threads with High CPU Utilization:">>$omiagent_trace_path
            echo "------------------------------------------------">>$omiagent_trace_path
            pt=(`top -b -H -p ${ppuc[$ind]} -n1|grep omiagent|tee -a $omiagent_trace_path|awk '{print $9;print $1}'`)

            if [ $incl_tsg_file -eq 1 ]; then
                pt=(`top -b -H -p ${ppuc[$ind]} -n1|grep omiagent|tee -a $tsg_omiagent_trace_path|awk '{print $9;print $1}'`)
            fi

            echo -e "\n\n" >>$omiagent_trace_path
            echo "Stacktrace:">>$omiagent_trace_path
            echo "----------------------------------------------">>$omiagent_trace_path
			echo -e "\n\n" >>$omiagent_trace_path
            echo "Stacktrace for Process: ${ppuc[$ind]}">>$omiagent_trace_path
            echo "----------------------------------------------">>$omiagent_trace_path
            sudo gdb -p ${ppuc[$ind]} -batch -ex "thread apply all bt" -ex quit &>> $omiagent_trace_path
	    sudo gdb -p ${ppuc[$ind]} -batch -ex "info sharedlibrary" -ex quit &>> $omiagent_trace_path

            while [ $index1 -lt ${#pt[@]} ]
            do
                if [ $(echo "${pt[$index1]} > $cpu_threshold"|bc) -eq 1 ]; then
                    ind1=`expr $index1 + 1`
                    echo -e "\n\n" >>$omiagent_trace_path
                    count1=0
                    echo "Stacktrace for Thread:${pt[$ind1]}">>$omiagent_trace_path
                    echo "----------------------------------------------">>$omiagent_trace_path
                    while [ $count1 -lt 5 ]
                    do
                        echo -e "\n\n" >>$omiagent_trace_path
                        echo "Stacktrace Snap Count: $count1">>$omiagent_trace_path
                        echo "----------------------------------------------">>$omiagent_trace_path
                        sudo gdb -p ${pt[$ind1]} -batch -ex "bt" -ex quit &>> $omiagent_trace_path
                        count1=`expr $count1 + 1`
                        sleep 2
                    done
                    dump_scx_omi_log_diff_tail
                fi
                index1=`expr $index1 + 2`
            done
  		fi
 		index=`expr $index + 2`
	done  

	sleep $rescan_interval_sec
	count=`expr $count - 1`
done

if [ ! -f $tsg_omiagent_trace_path ]; then
    echo "No threads with high CPU utilization.">>$tsg_omiagent_trace_path
fi

rm -f omiserver1.log scx1.log omiagent.root.root.1.log
