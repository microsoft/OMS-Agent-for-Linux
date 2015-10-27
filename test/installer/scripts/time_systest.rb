require 'test/unit'
require 'rexml/document'
require 'open-uri'

class Time_Test < Test::Unit::TestCase
  
  def test_time_skew()
    # Get the real time from nist
    url = "http://nist.time.gov/actualtime.cgi"
    source = open(url, &:read)
    doc = REXML::Document.new source
    nanosec_date_str = doc.root.attributes["time"]
    assert(nanosec_date_str.size >= 16)
    real_epoch = nanosec_date_str.to_i/1000/1000
    real_time = Time.at(real_epoch)
    
    system_epoch = Time.now.to_i
    
    err_msg = %(
Large system time offset detected.
Onboarding may fail with a 403 code.
System : #{Time.now}
Real   : #{real_time}
Use 'sudo date -s @#{real_epoch}'
)
    
    # Allow a max difference of 5 minutes
    max_delta = 5 * 60
    
    assert(real_epoch - max_delta < system_epoch, err_msg)
    assert(system_epoch < real_epoch + max_delta, err_msg)
  end

end
