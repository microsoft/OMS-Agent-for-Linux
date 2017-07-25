require 'test/unit'
require 'rexml/document'
require 'open-uri'

class Time_Test < Test::Unit::TestCase

  def test_time_skew()
    begin
      output = `ntpdate -q pool.ntp.org`
    rescue Errno::ENOENT
      print "Warning: ntpdate command not found; cannot run time skew test"
      return
    end

    assert_equal(0, $?, "ntpdate command failed with error code : #{$?}")
    offset_line = output[/offset (.*) sec/]
    assert(offset_line != nil, "Could not find the offset line in '#{output}'")
    offset = offset_line.gsub(/offset (.*) sec/, '\1').to_f

    err_msg = %(
Large system time offset detected.
Onboarding may fail with a 403 code.
System : #{Time.now}
Offset : #{offset}
)
    # Allow a max difference of 5 minutes between the computer time and the real time
    max_offset = 5 * 60
    assert(offset.abs < max_offset, err_msg)
  end

end
