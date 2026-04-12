# frozen_string_literal: true

require "digest"
require "json"
require "octaspace/transport/mock_transport"
require "octaspace/playground/payload_presets"
require "octaspace/playground/smoke_runner"

class ApplicationController < ActionController::Base
  after_action :shutdown_octa_client

  helper_method \
    :playground_diagnostics_preset_path,
    :octa_client,
    :playground_api_key_present?,
    :playground_auth_available?,
    :playground_config,
    :playground_error_payload,
    :playground_format_bytes,
    :playground_format_datetime,
    :playground_format_duration,
    :playground_format_short_time,
    :playground_json,
    :playground_json_html,
    :playground_masked_api_key,
    :playground_mock_active?,
    :playground_mock_scenario,
    :playground_mock_scenarios,
    :playground_asset_path,
    :playground_payload,
    :playground_present?,
    :playground_query_url,
    :playground_timeout_label,
    :playground_transport_description,
    :playground_transport_label,
    :playground_transport_stats,
    :playground_truncate

  private

  def octa_client
    @octa_client ||= begin
      client_options = {api_key: playground_effective_api_key}
      client_options[:base_url] = playground_effective_base_url if playground_base_url_override?
      client_options[:keep_alive] = false if playground_mock_active?

      if playground_mock_active?
        transport = OctaSpace::Transport::MockTransport.new(playground_config, scenario: playground_mock_scenario)
        OctaSpace::Client.new(**client_options, transport: transport)
      else
        OctaSpace::Client.new(**client_options)
      end
    end
  end

  def playground_config
    @playground_config ||= begin
      config = OctaSpace.configuration.dup
      config.api_key = playground_effective_api_key
      config.base_url = playground_effective_base_url
      config.keep_alive = false if playground_mock_active?
      config
    end
  end

  def playground_transport_stats
    @playground_transport_stats ||= octa_client.transport_stats
  end

  def playground_api_key_present?
    playground_config.api_key.present?
  end

  def playground_auth_available?
    playground_mock_active? || playground_api_key_present?
  end

  def playground_mock_active?
    playground_mock_scenario != "real"
  end

  def playground_mock_scenario
    value = playground_settings["mock_scenario"].presence || "real"
    playground_mock_scenarios.any? { |scenario| scenario[:value] == value } ? value : "real"
  end

  def playground_mock_scenarios
    OctaSpace::Transport::MockTransport.scenarios
  end

  def playground_payload(value)
    value.respond_to?(:data) ? value.data : value
  end

  def playground_diagnostics_preset_path(call_id, overrides = {})
    payload = OctaSpace::Playground::PayloadPresets.payload_for(call_id).merge(compact_present_hash(overrides))
    playground_diagnostics_path(call: call_id, payload_json: JSON.pretty_generate(payload))
  end

  def playground_asset_path(asset_name)
    asset_path = Rails.public_path.join(asset_name.to_s.delete_prefix("/"))
    return "/#{asset_name}" unless asset_path.file?

    fingerprint = Digest::SHA256.file(asset_path).hexdigest.first(12)
    "/#{asset_name}?v=#{fingerprint}"
  end

  def playground_present?(value)
    !value.nil?
  end

  def playground_json(value)
    JSON.pretty_generate(playground_serializable(value))
  rescue JSON::GeneratorError
    playground_serializable(value).inspect
  end

  def playground_json_html(value)
    render_json_node(playground_serializable(value), 0)
  end

  def playground_error_payload(error)
    payload = {
      class: error.class.name,
      message: error.message,
      status: error.status,
      request_id: error.request_id
    }

    response_data = error.response&.data
    payload[:response] = response_data if response_data.present?
    payload[:retry_after] = error.retry_after if error.respond_to?(:retry_after) && error.retry_after.present?
    payload.compact
  end

  def playground_query_url(param, value)
    url_for(request.path_parameters.merge(request.query_parameters).merge(param.to_s => value, only_path: true))
  end

  def playground_masked_api_key
    key = playground_config.api_key.to_s
    return "" if key.empty?
    return ("*" * key.length) if key.length <= 8

    "#{key[0, 4]}#{'*' * [key.length - 8, 4].max}#{key[-4, 4]}"
  end

  def playground_transport_label
    return playground_selected_scenario[:label] if playground_mock_active?

    playground_config.keep_alive? ? "Real API / Keep-Alive" : "Real API"
  end

  def playground_transport_description
    return playground_selected_scenario[:description] if playground_mock_active?

    playground_config.keep_alive? ? "Uses the real API through the persistent transport" : "Uses the real API through the standard Faraday transport"
  end

  def playground_timeout_label
    "#{playground_config.open_timeout}s / #{playground_config.read_timeout}s"
  end

  def playground_format_duration(value)
    seconds = value.to_i
    return "—" if seconds <= 0

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    remainder = seconds % 60

    return "#{hours}h #{minutes}m" if hours.positive?
    return "#{minutes}m #{remainder}s" if minutes.positive?

    "#{remainder}s"
  end

  def playground_format_bytes(value)
    bytes = value.to_f
    return "0 B" unless bytes.positive?

    units = %w[B KB MB GB TB]
    index = 0

    while bytes >= 1024 && index < units.length - 1
      bytes /= 1024.0
      index += 1
    end

    format("%.1f %s", bytes, units[index])
  end

  def playground_format_datetime(value)
    return "—" if value.blank?

    timestamp =
      case value
      when Time, DateTime, ActiveSupport::TimeWithZone
        value
      when Numeric
        numeric = value.to_f
        numeric > 10_000_000_000 ? Time.zone.at(numeric / 1000.0) : Time.zone.at(numeric)
      else
        Time.zone.parse(value.to_s)
      end

    timestamp&.strftime("%b %-d, %H:%M") || "—"
  rescue ArgumentError, TypeError
    value.to_s
  end

  def playground_format_short_time(value)
    return "—" if value.blank?

    timestamp =
      case value
      when Time, DateTime, ActiveSupport::TimeWithZone
        value
      when Numeric
        value.to_f > 10_000_000_000 ? Time.zone.at(value.to_f / 1000.0) : Time.zone.at(value.to_f)
      else
        Time.zone.parse(value.to_s)
      end

    timestamp&.strftime("%H:%M:%S") || value.to_s
  rescue ArgumentError, TypeError
    value.to_s
  end

  def playground_truncate(value, leading: 8, trailing: 5)
    string = value.to_s
    return string if string.length <= (leading + trailing + 1)

    "#{string[0, leading]}…#{string[-trailing, trailing]}"
  end

  def playground_serializable(value)
    serializable = playground_payload(value)

    case serializable
    when OctaSpace::Error
      playground_error_payload(serializable)
    when Hash, Array, String, Numeric, TrueClass, FalseClass, NilClass
      serializable
    when Symbol
      serializable.to_s
    else
      serializable.respond_to?(:to_h) ? serializable.to_h : serializable.to_s
    end
  end

  def compact_present_hash(hash)
    hash.each_with_object({}) do |(key, value), result|
      result[key] = value if value.present?
    end
  end

  def render_json_node(node, level)
    case node
    when Hash
      render_json_hash(node, level)
    when Array
      render_json_array(node, level)
    when String
      %(<span class="json-string">#{ERB::Util.html_escape(node.to_json)}</span>).html_safe
    when Numeric
      %(<span class="json-number">#{node}</span>).html_safe
    when TrueClass, FalseClass
      %(<span class="json-bool">#{node}</span>).html_safe
    when NilClass
      %(<span class="json-null">null</span>).html_safe
    else
      %(<span class="json-string">#{ERB::Util.html_escape(node.to_s.to_json)}</span>).html_safe
    end
  end

  def render_json_hash(hash, level)
    return "{}".html_safe if hash.empty?

    lines = hash.map do |key, value|
      %(#{json_indent(level + 1)}<span class="json-key">#{ERB::Util.html_escape(key.to_s.to_json)}</span>: #{render_json_node(value, level + 1)})
    end

    "{\n#{lines.join(",\n")}\n#{json_indent(level)}}".html_safe
  end

  def render_json_array(array, level)
    return "[]".html_safe if array.empty?

    lines = array.map do |value|
      "#{json_indent(level + 1)}#{render_json_node(value, level + 1)}"
    end

    "[\n#{lines.join(",\n")}\n#{json_indent(level)}]".html_safe
  end

  def json_indent(level)
    "  " * level
  end

  def shutdown_octa_client
    @octa_client&.shutdown
    @octa_client = nil
  end

  def playground_settings
    session[:playground_settings] ||= {}
  end

  def playground_selected_scenario
    playground_mock_scenarios.find { |scenario| scenario[:value] == playground_mock_scenario } || playground_mock_scenarios.first
  end

  def playground_effective_api_key
    if playground_settings.key?("api_key")
      playground_settings["api_key"].to_s
    else
      OctaSpace.configuration.api_key.to_s
    end
  end

  def playground_effective_base_url
    if playground_base_url_override?
      playground_settings["base_url"].to_s
    else
      OctaSpace.configuration.base_url.to_s
    end
  end

  def playground_base_url_override?
    playground_settings["base_url"].present?
  end
end
