require 'test/unit'
require_relative '../../../installer/scripts/auth_key.rb'

class Auth_Test < Test::Unit::TestCase

  def setup
    test_dir = File.dirname(__FILE__)
    @body_onboard_path1 = "#{test_dir}/body_onboard_test1.xml"
    @shared_key_path1   = "#{test_dir}/shared_key_test1"
    @date_str1          = "2015-10-09T22:51:19.259645500-07:00"
    @expected_hash1     = "5PWvuBVXOgrizTvwU/n9IVA7wgKDj4ihFVWUhb9j9s0="
    @expected_auth_key1 = "K6h/Cxyr4lYZPX4WiKwgbwUnumOSAFa71AQIz6VnDpw="
  end

  def test_content_hash()
    content_hash = get_content_hash(@body_onboard_path1)
    assert_equal(@expected_hash1, content_hash, "Content hash of #{@body_onboard_path1} does not match")
  end

  def test_auth_key()
    content_hash = get_content_hash(@body_onboard_path1)
    auth_key = get_auth_key(@date_str1, content_hash, @shared_key_path1)
    assert_equal(@expected_auth_key1, auth_key)
  end

  def test_content_hash_fake_file()
    assert_raise RuntimeError do
      get_content_hash("fake_file")
    end
  end

  def test_auth_str()
    auth_str = get_auth_str(@date_str1, @body_onboard_path1, @shared_key_path1)
    assert_equal("#{@expected_hash1} #{@expected_auth_key1}", auth_str)
  end

end
