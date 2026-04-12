# frozen_string_literal: true

require "test_helper"

class OctaSpace::AppsResourceTest < Minitest::Test
  def setup
    super
    @client = test_client
  end

  def test_list_returns_array
    stub_get("/apps", fixture_path: "apps/index.json")
    response = @client.apps.list
    assert response.success?
    assert_kind_of Array, response.data
    assert_equal 2, response.data.size
    assert_equal "Stable Diffusion", response.data.first["name"]
  end

  def test_list_passes_params
    stub_request(:get, "#{StubHelpers::BASE_URL}/apps")
      .with(query: {"category" => "AI"})
      .to_return(status: 200, body: "[]", headers: json_headers)
    response = @client.apps.list(category: "AI")
    assert response.success?
  end

  def test_list_raises_authentication_error_on_401
    stub_error(:get, "/apps", status: 401, message: "Unauthorized")
    assert_raises(OctaSpace::AuthenticationError) { @client.apps.list }
  end
end
