# Change Tracking Testing

Change tracking solution was introduced to oms in [this commit]
(https://github.com/Microsoft/OMS-Agent-for-Linux/commit/5fc6ffeb2442d390cfa55f1c7b69628d02938e2d).
It is available in builds >= 111.

## How it works
Omsagent periodically invokes an [in_exec plugin](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/installer/conf/omsagent.d/change_tracking.conf).

This calls `/opt/microsoft/omsconfig/Scripts/PerformInventory.py`</br>
We then read in this mof `/etc/opt/omi/conf/omsconfig/configuration/Inventory.mof`</br>
The ressources in the mof generate the xml file `/etc/opt/omi/conf/omsconfig/configuration/Inventory.xml`</br>
The generated xml file content is passed as text to the omsagent/fluentd pipeline.

## Installation
`sudo ./omsagent-1.1.0-111.universal.x64.sh --install -w <Workspace ID> -s <Shared Key>`

Switch to the omsagent user and create the file `/etc/opt/omi/conf/omsconfig/configuration/Inventory.mof` if it doesn't exist.
```
sudo su omsagent
vi /etc/opt/omi/conf/omsconfig/configuration/Inventory.mof
```

Set the content of the file to:
```
instance of MSFT_nxPackageResource
{
 Name = "*";
 ResourceId = "[MSFT_nxPackageResource]Inventory";
 ModuleName = "nx";
 ModuleVersion = "1.0";
};

instance of MSFT_nxServiceResource
{
 Name = "*";
 Controller = "init";
 ResourceId = "[MSFT_nxFileResource]Inventory";
 ModuleName = "nx";
 ModuleVersion = "1.0";
};

instance of OMI_ConfigurationDocument
{
 DocumentType = "inventory";
 Version="2.0.0";
 MinimumCompatibleVersion = "2.0.0";
 CompatibleVersionAdditionalProperties= { "MSFT_DSCMetaConfiguration:StatusRetentionTimeInDays" };
 Author="azureautomation";
 GenerationDate="04/17/2015 11:41:09";
 GenerationHost="azureautomation-01";
 Name="RegistrationMetaConfig";
};
```

You might have to change the line `Controller = "init";` to `Controller = "systemd";` or `Controller = "*";` depending on the system/features. 

## Debug output
 - In `/etc/opt/microsoft/omsagent/conf/omsagent.conf` replace `log_level info` by `log_level trace` int the `out_oms` output plugin configuration.
 - In `/etc/opt/microsoft/omsagent/conf/omsagent.d/change_tracking.conf` change the `log_level` of the filters to `trace` as well.
 - Restart omsagent for the configuration changes to take effect. `sudo service omsagent restart`

## Testing
It's helpfull to have a window streaming the log messages from omsagent with:</br>
`tail -f /var/opt/microsoft/omsagent/log/omsagent.log`

The first time that services are buffered there should be similar to this in the log:</br>
```
2016-03-31 14:56:49 -0700 [debug]: ChangeTracking : Packages x 1373, Services x 1
2016-03-31 14:56:49 -0700 [trace]: Buffering oms.changetracking.service
[...]
2016-03-31 15:04:36 -0700 [debug]: Success sending oms.changetracking.service x 2 in 0.7s
```

Normally the next change tracking logs will look like this because we discard identical data:
```
2016-03-31 15:04:50 -0700 [debug]: ChangeTracking : Filtering xml size=2487950
2016-03-31 15:04:50 -0700 [debug]: ChangeTracking : Discarding duplicate inventory data. Hash=f885e3
```

If a service or package changes on the machine, the hash should change and we should send inventory data again.
For example, if we add a package `sudo yum install kmines -y`
We should get in the logs: 
```
2016-03-31 15:08:37 -0700 [debug]: ChangeTracking : Filtering xml size=2489697
2016-03-31 15:08:41 -0700 [debug]: ChangeTracking : Packages x 1374, Services x 1
2016-03-31 15:08:41 -0700 [trace]: Buffering oms.changetracking.service
[...]
2016-03-31 15:08:56 -0700 [debug]: ChangeTracking : Filtering xml size=2489697
2016-03-31 15:08:56 -0700 [debug]: ChangeTracking : Discarding duplicate inventory data. Hash=a1e0c8
2016-03-31 15:08:57 -0700 [debug]: Success sending oms.changetracking.service x 2 in 1.37s
```

In the [OMS portal](mms.microsoft.com) there should be an entry for the new package. This might take up to 30 minutes because the diff service is executed periodically.

The same kind of testing can be done for services.

## Troubleshooting

### Services x 1

In the example above, we have `Services x 1` This is because `initd` was setup as the controller in the mof instead of `systemd` for this system. After using the correct one we get :</br>
`2016-03-31 15:53:36 -0700 [debug]: ChangeTracking : Packages x 1374, Services x 212`

### Filtering xml size < 1000

If you see `ChangeTracking : Filtering xml size=158` where `size < 1000` the mof is probably incorrect.</br>
Run as omsagent `python /opt/microsoft/omsconfig/Scripts/PerformInventory.py` and inspect the generated file `/etc/opt/omi/conf/omsconfig/configuration/Inventory.xml`. </br>
There is a [ruby script](https://github.com/Microsoft/OMS-Agent-for-Linux/blob/master/test/code/plugins/prettyfyxml.rb) in the omsagent source that can help you format the resulting xml : `test/code/plugins/prettyfyxml.rb`

### MI_RESULT_INVALID_NAMESPACE

Make sure the .reg files are in the right place in:
`/etc/opt/omi/conf/omiregister`

Check the registration files:
`/etc/opt/omi/conf/omsconfig/configuration/registration/MSFT_nxPackageResource/MSFT_nxPackageResource.registration.mof`
And
`../MSFT_nxServiceResource/MSFT_nxServiceResource.registration.mof`

Change:
`Namespace = "root/Microsoft/DesiredStateConfiguration";`
To
`Namespace = "root/oms";`
