require "test_helper"

class SnakommitTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Snakommit::VERSION
  end

  def test_version_follows_semantic_versioning
    assert_match(/^\d+\.\d+\.\d+$/, ::Snakommit::VERSION)
  end
end 