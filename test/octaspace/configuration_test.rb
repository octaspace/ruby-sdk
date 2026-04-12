# frozen_string_literal: true

require "test_helper"

class OctaSpace::ConfigurationTest < Minitest::Test
  def test_defaults
    config = OctaSpace::Configuration.new
    assert_equal "https://api.octa.space", config.base_url
    assert_equal 10, config.open_timeout
    assert_equal 30, config.read_timeout
    assert_equal false, config.keep_alive
    assert_equal 5, config.pool_size
    assert_equal 2, config.max_retries
    assert_equal true, config.ssl_verify
  end

  def test_keep_alive_predicate
    config = OctaSpace::Configuration.new
    refute config.keep_alive?
    config.keep_alive = true
    assert config.keep_alive?
  end

  def test_persistent_alias
    config = OctaSpace::Configuration.new
    config.persistent = true
    assert config.keep_alive?
    assert config.persistent
  end

  def test_urls_single_base_url
    config = OctaSpace::Configuration.new
    config.base_url = "https://api.octa.space"
    assert_equal ["https://api.octa.space"], config.urls
  end

  def test_urls_base_urls_takes_priority
    config = OctaSpace::Configuration.new
    config.base_url = "https://api.octa.space"
    config.base_urls = ["https://a.octa.space", "https://b.octa.space"]
    assert_equal ["https://a.octa.space", "https://b.octa.space"], config.urls
  end

  def test_dup_creates_independent_copy
    config = OctaSpace::Configuration.new
    copy = config.dup
    copy.api_key = "different"
    assert_nil config.api_key
  end

  def test_user_agent_contains_version
    config = OctaSpace::Configuration.new
    assert_includes config.user_agent, OctaSpace::VERSION
    assert_includes config.user_agent, RUBY_VERSION
  end

  def test_configure_block
    OctaSpace.configure do |c|
      c.api_key = "my_key"
      c.keep_alive = true
    end
    assert_equal "my_key", OctaSpace.configuration.api_key
    assert OctaSpace.configuration.keep_alive?
  end
end
