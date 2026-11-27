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

  def test_reads_key_and_url_from_env
    with_env("OCTA_API_KEY" => " octa_ak_fromenv ", "OCTA_API_URL" => "https://a.example/") do
      config = OctaSpace::Configuration.new
      assert_equal "octa_ak_fromenv", config.api_key
      assert_equal ["https://a.example"], config.urls
    end
  end

  def test_env_url_list_sets_base_urls
    with_env("OCTA_API_URL" => "https://a.example, https://b.example") do
      assert_equal ["https://a.example", "https://b.example"], OctaSpace::Configuration.new.urls
    end
  end

  def test_client_uses_env_key_unless_given_one
    with_env("OCTA_API_KEY" => "octa_ak_fromenv") do
      OctaSpace.reset_configuration!
      stub_request(:get, "#{StubHelpers::BASE_URL}/accounts/balance").to_return(status: 200, body: "{}")
      OctaSpace::Client.new.accounts.balance
      assert_requested(:get, "#{StubHelpers::BASE_URL}/accounts/balance",
        headers: {"Authorization" => "Bearer octa_ak_fromenv"})

      assert_raises(OctaSpace::AuthenticationError) { OctaSpace::Client.new(api_key: "").accounts.balance }
    end
  end

  def test_keep_alive_predicate
    config = OctaSpace::Configuration.new
    refute config.keep_alive?
    config.keep_alive = true
    assert config.keep_alive?
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

  def test_api_key_is_normalized
    config = OctaSpace::Configuration.new
    config.api_key = "  Bearer octa_ak_x \n"
    assert_equal "octa_ak_x", config.api_key
    assert config.api_key?

    config.api_key = "   "
    assert_nil config.api_key
    refute config.api_key?
  end

  def test_urls_strip_trailing_slashes_and_blanks
    config = OctaSpace::Configuration.new
    config.base_urls = ["https://a.example/", "", " https://b.example// "]
    assert_equal ["https://a.example", "https://b.example"], config.urls
  end

  def test_configure_block
    OctaSpace.configure do |c|
      c.api_key = "my_key"
      c.keep_alive = true
    end
    assert_equal "my_key", OctaSpace.configuration.api_key
    assert OctaSpace.configuration.keep_alive?
  end

  private

  def with_env(vars)
    saved = vars.keys.to_h { |key| [key, ENV[key]] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
