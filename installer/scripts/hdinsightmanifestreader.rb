cluster_name=`sudo python -c "from hdinsight_common.AmbariHelper import AmbariHelper; print AmbariHelper().get_cluster_manifest().deployment.cluster_name"`
# old clusters manifest does not have this field
has_cluster_type=`sudo python -c "from hdinsight_common.AmbariHelper import AmbariHelper; print AmbariHelper().get_cluster_manifest().settings.has_key('cluster_type')"`
cluster_type = "Unknown cluster type"
if has_cluster_type.strip == "True"
   cluster_type = `sudo python -c "from hdinsight_common.AmbariHelper import AmbariHelper; print AmbariHelper().get_cluster_manifest().settings['cluster_type']"`
end
results = '{"cluster_name":"'+ cluster_name.strip + '", "cluster_type":"'+ cluster_type.strip + '"}'
puts results