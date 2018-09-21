$images = ("ubuntu14", "ubuntu16", "ubuntu18", "debian8", "debian9","centos6", "oracle6", "oracle7")
$omsbundle="<oms-bundlefile-name>"
$workspaceId="<workspace-id>"
$workspaceKey="<workspace-key>"

Foreach ($image in $images)
{
    $container = "$image-container"
    # docker container stop $container
    # docker container rm $container

    docker run --name $container -it --privileged=true -d $image
    docker cp $omsbundle ${container}:/home/temp/$omsbundle
    docker cp omsinstall.sh ${container}:/home/temp/omsinstall.sh
    docker cp perf.conf ${container}:/home/temp/perf.conf
    docker exec $container sh /home/temp/$omsbundle --purge
    docker exec $container sh /home/temp/$omsbundle --upgrade -w $workspaceId -s $workspaceKey
    docker exec $container sh /home/temp/omsinstall.sh
}