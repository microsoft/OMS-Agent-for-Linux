require 'test/unit'
require_relative 'omstestlib'
require_relative ENV['BASE_DIR'] + '/source/code/plugins/security_lib'

class SecurityLibTest < Test::Unit::TestCase

  def test_valid_tags
    asa_tag_1 = '%ASA-1-106100'
    asa_tag_2 = '%ASA-6-106012'
    cef_tag = 'CEF'

    asa_type = OMS::Security.log_type_mapping['%ASA']
    cef_type = OMS::Security.log_type_mapping['CEF']

    assert_equal(OMS::Security.get_data_type(asa_tag_1), asa_type, "Wrong type for tag '#{asa_tag_1}'. Expected: '#{asa_type}'")
    assert_equal(OMS::Security.get_data_type(asa_tag_2), asa_type, "Wrong type for tag '#{asa_tag_2}'. Expected: '#{asa_type}'")
    assert_equal(OMS::Security.get_data_type(cef_tag), cef_type, "Wrong type for tag '#{cef_tag}'. Expected: '#{cef_type}'")
  end

  def test_invalid_tags
    invalid_tags = [nil, '', 'CE', 'ASA-2-102300', '%SA-4-123223', '$ASA-1-31123', '%#:', '.']
    invalid_tags.each do |tag|
      assert_equal(nil, OMS::Security.get_data_type(tag), "Type found for invalid tag '#{tag}'")
    end
  end
end
