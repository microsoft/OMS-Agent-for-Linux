result=`sudo python -c "from hdinsight_common.AmbariHelper import AmbariHelper; print AmbariHelper().get_cluster_manifest().deployment.cluster_name"`
puts result