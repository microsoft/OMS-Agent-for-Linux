require 'fluent/test'
require_relative ENV['BASE_DIR'] + '/source/ext/fluentd/test/helper'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/out_oms_changetracking_file'
require_relative 'omstestlib'
require_relative 'out_oms_systestbase'

class TestableOutChangeTrackingFile < Fluent::OutChangeTrackingFile
    def initialize
      super
    end

    append_blob_log = {}

    def append_blob(uri, msgs, file_path)
        @append_blob_log[file_path] = uri
    end
    def get_append_blob_log
        return @append_blob_log
    end
    def clear_append_blob_log
        @append_blob_log ={}
    end
end

class OutOMSChangeTrackingFileTest < OutOMSSystemTestBase

  def test_send_data
    # Onboard to create cert and key
    prep_onboard
    do_onboard

    conf = load_configurations

    tag = 'out_oms_oms.changetracking.file'
    d = Fluent::Test::OutputTestDriver.new(TestableOutChangeTrackingFile, tag)
    output = d.configure(conf).instance
    output.set_ContentlocationUri("http://abc.blob.core.net/changetracking")
    output.set_PrimaryContentLocationAccessToken("xyz")
    output.set_SecondaryContentLocationAccessToken("pqr")
    output.set_ContentlocationUriResourceId("subscription/subname/groupname/group/accountname/account")
    output.start

    assert_equal("http://abc.blob.core.net/changetracking", output.get_ContentlocationUri, "Content Location Uri not found : '#{output.get_ContentlocationUri}'")
    assert_equal("subscription/subname/groupname/group/accountname/account", output.get_ContentlocationUriResourceId, "Content Location Resource not found : '#{output.get_ContentlocationUriResourceId}'")

   $log.clear
   record = {
              "DataType"=>"CONFIG_CHANGE_BLOB",
              "IPName"=>"changetracking",
              "DataItems"=>[
                {
                    "Timestamp" => "2016-08-20T18:12:22.000Z",
                    "Computer" => "host",
                    "ConfigChangeType"=> "Files",
                    "Collections"=>
		             [{"CollectionName"=>"/etc/yum.conf",
		               "Contents"=>"1000",
		               "DateCreated"=>"2016-08-20T18:12:22.000Z",
		               "DateModified"=>"2016-08-20T18:12:22.000Z",
		               "FileSystemPath"=>"/etc/yum.conf",
		               "Group"=>"root",
		               "Mode"=>"644",
		               "Owner"=>"root",
		               "Size"=>"835"}]
                }
              ]
            }

    assert(output.handle_records(tag, record), "Failed to send change tracking updates data : '#{$log.logs}'")

   $log.clear
   record = {
              "DataType"=>"CONFIG_CHANGE_BLOB",
              "IPName"=>"changetracking",
              "DataItems"=>[
                {
                    "Timestamp" => "2016-08-20T18:12:22.000Z",
                    "Computer" => "host",
                    "ConfigChangeType"=> "Files",
                    "Collections"=>
		             [{"CollectionName"=>"/etc/yum.conf",
		               "Contents"=>"1000",
		               "DateCreated"=>"2016-08-20T18:12:22.000Z",
		               "DateModified"=>"2016-08-20T18:12:22.000Z",
		               "FileSystemPath"=>"/etc/yum.conf",
                               "FileContentBlobLink"=>" ",
		               "Group"=>"root",
		               "Mode"=>"644",
		               "Owner"=>"root",
		               "Size"=>"835"},
		             {"CollectionName"=>"/etc/yum1.conf",
		               "Contents"=>"1000",
		               "DateCreated"=>"2016-08-20T18:12:22.000Z",
		               "DateModified"=>"2016-08-20T18:12:22.000Z",
		               "FileSystemPath"=>"/etc/yum1.conf",
		               "Group"=>"root",
		               "Mode"=>"644",
		               "Owner"=>"root",
		               "Size"=>"835"}]
                }
              ]
            }
    output.clear_append_blob_log()
    assert(output.handle_records(tag, record), "Failed to send change tracking updates data : '#{$log.logs}'")
    append_blob_log = output.get_append_blob_log()
    assert_not_nil(append_blob_log)
    assert_equal(append_blob_log["/etc/yum.conf"],  "http://abc.blob.core.net/changetracking/#{OMS::Common.get_hostname}/#{OMS::Configuration.agent_id}/2016-08-20T18:12:22.000Z-yum.conf?xyz")
    assert_equal(append_blob_log["/etc/yum1.conf"], nil)


   $log.clear
   record = {
              "DataType"=>"CONFIG_CHANGE_BLOB",
              "IPName"=>"changetracking",
              "DataItems"=>[
                {
                    "Timestamp" => "2016-08-20T18:12:22.000Z",
                    "Computer" => "host",
                    "ConfigChangeType"=> "Files",
                    "Collections"=>
		             [{"CollectionName"=>"/etc/yum.conf",
		               "Contents"=>"1000",
		               "DateCreated"=>"2016-08-20T18:12:22.000Z",
		               "DateModified"=>"2016-08-20T18:12:22.000Z",
		               "FileSystemPath"=>"/etc/yum.conf",
                               "FileContentBlobLink"=>" ",
		               "Group"=>"root",
		               "Mode"=>"644",
		               "Owner"=>"root",
		               "Size"=>"835"},
		             {"CollectionName"=>"/etc/yum1.conf",
		               "Contents"=>"1000",
		               "DateCreated"=>"2016-08-20T18:12:22.000Z",
		               "DateModified"=>"2016-08-20T18:12:22.000Z",
		               "FileSystemPath"=>"/etc/yum1.conf",
		               "Group"=>"root",
		               "Mode"=>"644",
		               "Owner"=>"root",
		               "Size"=>"835"}]
                }
              ]
            }
    collection = output.get_changed_files(record)
    assert_not_nil(collection, "changed files should not be nil")
    assert_not_nil(collection["/etc/yum.conf"])
    assert_equal(collection["/etc/yum.conf"], "http://abc.blob.core.net/changetracking/#{OMS::Common.get_hostname}/#{OMS::Configuration.agent_id}/2016-08-20T18:12:22.000Z-yum.conf")
    assert_equal(collection["/etc/yum1.conf"], nil)

    expected_changed_record = {"DataItems"=>
  [{"Collections"=>
     [{"CollectionName"=>"/etc/yum.conf",
       "Contents"=>"1000",
       "DateCreated"=>"2016-08-20T18:12:22.000Z",
       "DateModified"=>"2016-08-20T18:12:22.000Z",
       "FileContentBlobLink"=>
        "http://abc.blob.core.net/changetracking/#{OMS::Common.get_hostname}/#{OMS::Configuration.agent_id}/2016-08-20T18:12:22.000Z-yum.conf?resourceid=subscription/subname/groupname/group/accountname/account",
       "FileSystemPath"=>"/etc/yum.conf",
       "Group"=>"root",
       "Mode"=>"644",
       "Owner"=>"root",
       "Size"=>"835"},
      {"CollectionName"=>"/etc/yum1.conf",
       "Contents"=>"1000",
       "DateCreated"=>"2016-08-20T18:12:22.000Z",
       "DateModified"=>"2016-08-20T18:12:22.000Z",
       "FileContentBlobLink"=>
        "http://abc.blob.core.net/changetracking/#{OMS::Common.get_hostname}/#{OMS::Configuration.agent_id}/2016-08-20T18:12:22.000Z-yum1.conf?resourceid=subscription/subname/groupname/group/accountname/account",
       "FileSystemPath"=>"/etc/yum1.conf",
       "Group"=>"root",
       "Mode"=>"644",
       "Owner"=>"root",
       "Size"=>"835"}],
    "Computer"=>"host",
    "ConfigChangeType"=>"Files",
    "Timestamp"=>"2016-08-20T18:12:22.000Z"}],
 "DataType"=>"CONFIG_CHANGE_BLOB",
 "IPName"=>"changetracking"}
    changed_record = output.update_records_with_upload_url(record)
    assert_equal(changed_record, expected_changed_record)
  end
end
