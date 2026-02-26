require 'rails_helper'
require 'ostruct'

RSpec.describe Api::V3::ApiController,
               type: :request,
               api_v3_integration: true,
               api_journey: true do
  let(:scope) { 'create read update delete digest' }
  let(:headers) { v3_auth_headers(scope: scope) }
  let(:suffix) { "#{Time.now.to_i}_#{SecureRandom.hex(3)}" }
  let(:strict_mode) { ENV.fetch('API_JOURNEY_STRICT', '1').to_s == '1' }

  let(:namespace_name) { "e2e_api_journey_#{suffix}" }
  let(:namespace_slug) { namespace_name.downcase }
  let!(:namespace) { Setup::Namespace.where(name: namespace_name).first || Setup::Namespace.create!(name: namespace_name) }
  let(:data_type_name) { "Lead#{suffix.delete('_')}" }
  let(:record_name) { "Lead Record #{suffix}" }
  let(:template_name) { "LeadTemplate#{suffix.delete('_')}" }
  let(:flow_name) { "LeadFlow#{suffix.delete('_')}" }
  let(:webhook_name) { "LeadWebhook#{suffix.delete('_')}" }

  let(:created_ids) do
    {
      data_type: nil,
      template: nil,
      webhook: nil,
      flow: nil,
      record: nil,
      model_slug: nil
    }
  end
  let(:fallback_notes) { [] }

  def resolve_type_id!(name)
    id = resolve_data_type_id_via_api(namespace: 'Setup', name: name, headers: headers)
    id ||= ::Setup::BuildInDataType["Setup::#{name}"]&.id&.to_s
    expect(id).to be_present, "expected Setup::#{name} data type id to be present"
    id
  end

  def create_via_data_type_digest!(type_id, payload, lookup_namespace:, lookup_name:, lookup_model: 'data_type')
    post_json("/api/v3/setup/data_type/#{type_id}/digest", params: payload, headers: headers)
    expect_status_in(:ok, :created, :accepted)
    body = json_response
    resolved_id = resolve_id_from_hash(body)
    unless resolved_id
      get_json(
        "/api/v3/setup/#{lookup_model}",
        params: { namespace: lookup_namespace, name: lookup_name, limit: 1 },
        headers: headers
      )
      expect_status_in(:ok)
      resolved_id = resolve_id_from_hash(json_response.dig('items', 0))
    end
    unless resolved_id
      model_class = "Setup::#{lookup_model.camelize}".safe_constantize
      resolved_id = model_class.where(namespace: lookup_namespace, name: lookup_name).first&.id&.to_s if model_class
    end
    body['id'] = resolved_id if resolved_id
    expect(body['id']).to be_present
    body
  end

  def wait_for_flow_execution(flow_id, headers:, execution_id: nil, timeout: 30)
    flow_oid =
      begin
        BSON::ObjectId.from_string(flow_id.to_s)
      rescue StandardError
        nil
      end
    started = Time.now
    loop do
      execution = nil
      if execution_id.present?
        get_json("/api/v3/setup/execution/#{execution_id}", headers: headers)
        if response.status == 200
          execution = OpenStruct.new(id: execution_id, status: json_response['status'])
        end
      end
      execution ||=
        if flow_oid
          ::Setup::Execution.where(agent_id: flow_oid).desc(:_id).first
        else
          ::Setup::Execution.where(agent_id: flow_id).desc(:_id).first
        end
      unless execution
        task =
          if flow_oid
            ::Setup::FlowExecution.where(flow_id: flow_oid).desc(:_id).first
          else
            ::Setup::FlowExecution.where(flow_id: flow_id).desc(:_id).first
          end
        execution = task&.current_execution || task&.executions&.desc(:_id)&.first
      end
      return execution if execution.present?
      break if Time.now - started > timeout

      sleep 1
    end
    nil
  end

  def wait_for_record_id(namespace_slug:, model_slug:, query:, timeout: 30)
    started = Time.now
    loop do
      get_json(
        "/api/v3/#{namespace_slug}/#{model_slug}",
        params: query.merge(limit: 1),
        headers: headers
      )
      expect_status_in(:ok)
      record = json_response.fetch('items', []).find { |item| query.all? { |k, v| item[k.to_s] == v } }
      record_id = resolve_id_from_hash(record)
      return record_id if record_id.present?
      break if Time.now - started > timeout

      sleep 1
    end
    nil
  end

  def delete_if_present(path)
    delete_json(path, headers: headers)
    expect_status_in(:ok, :no_content, :not_found, :unprocessable_entity, :not_acceptable, :unauthorized, :forbidden)
  rescue StandardError
    # Best-effort cleanup by design.
  end

  it 'runs full API journey: data type -> template -> webhook -> flow -> record -> flow trigger' do
    data_type = Setup::JsonDataType.create!(
      namespace: namespace_name,
      name: data_type_name,
      schema: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          email: { type: 'string' }
        }
      }
    )
    created_ids[:data_type] = data_type.id.to_s
    created_ids[:model_slug] = data_type.slug

    template = Setup::LiquidTemplate.create!(
      namespace: namespace_name,
      name: template_name,
      source_data_type: data_type,
      code: '{{name}}'
    )
    created_ids[:template] = template.id.to_s

    webhook = Setup::PlainWebhook.create!(
      namespace: namespace_name,
      name: webhook_name,
      path: "/e2e/#{namespace_slug}/#{webhook_name.underscore}",
      method: 'post'
    )
    created_ids[:webhook] = webhook.id.to_s

    flow = Setup::Flow.create!(
      namespace: namespace_name,
      name: flow_name,
      translator: template,
      webhook: webhook
    )
    created_ids[:flow] = flow.id.to_s

    create_record_headers = v3_digest_headers(
      template_options: { viewport: {}, include_id: true },
      headers: headers
    )

    post_json(
      "/api/v3/#{namespace_slug}/#{created_ids[:model_slug]}",
      params: { name: record_name, email: "lead-#{suffix}@cenit.io" },
      headers: create_record_headers
    )
    create_record_status = response.status
    create_record_body = response.body.to_s
    expect_status_in(:ok, :created, :accepted)
    created_ids[:record] = resolve_id_from_hash(json_response)
    created_ids[:record] ||= wait_for_record_id(
      namespace_slug: namespace_slug,
      model_slug: created_ids[:model_slug],
      query: { name: record_name }
    )
    unless created_ids[:record]
      if strict_mode
        raise "API_JOURNEY_STRICT=1: record id was not materialized by API POST/list for #{namespace_slug}/#{created_ids[:model_slug]}; create_status=#{create_record_status}; create_body=#{create_record_body}"
      end
      # Known backend test limitation: dynamic model POST can return accepted without
      # exposing a stable id shape immediately for custom data type records.
      fallback_notes << 'record_creation_fallback_used'
      model_class = data_type.records_model
      created_record = model_class.new(
        name: record_name,
        email: "lead-#{suffix}@cenit.io"
      )
      expect(created_record.save).to be_truthy
      created_ids[:record] = created_record.id.to_s
    end
    expect(created_ids[:record]).to be_present

    get_json(
      "/api/v3/#{namespace_slug}/#{created_ids[:model_slug]}",
      params: { name: record_name, limit: 1 },
      headers: headers
    )
    expect_status_in(:ok)
    listed = json_response.fetch('items', [])
    expect(listed.map { |item| item['name'] }).to include(record_name)
    listed_record = listed.detect { |item| item['name'] == record_name }
    listed_id = resolve_id_from_hash(listed_record)
    created_ids[:record] = listed_id if listed_id.present?

    post_json(
      "/api/v3/setup/flow/#{created_ids[:flow]}/digest",
      params: {
        data_type_id: created_ids[:data_type],
        source_id: created_ids[:record]
      },
      headers: headers
    )
    flow_digest_status = response.status
    flow_digest_body = response.body.to_s
    flow_digest_execution_id = resolve_id_from_hash(json_response)
    expect_status_in(:ok, :accepted, :created)

    execution =
      if flow_digest_execution_id.present? && json_response['status'].present?
        OpenStruct.new(id: flow_digest_execution_id, status: json_response['status'])
      else
        wait_for_flow_execution(created_ids[:flow], headers: headers, execution_id: flow_digest_execution_id, timeout: 30)
      end
    unless execution
      raise "API_JOURNEY_STRICT=1: flow digest did not produce execution evidence for flow #{created_ids[:flow]} (status=#{flow_digest_status}, execution_id=#{flow_digest_execution_id.inspect}, body=#{flow_digest_body})"
    end
    expect(execution).to be_present
    expect(execution.status).to be_present
    fallback_notes.each { |note| RSpec.configuration.reporter.message("KNOWN_LIMITATION: #{note}") }
  ensure
    if created_ids[:record] && created_ids[:model_slug]
      delete_if_present("/api/v3/#{namespace_slug}/#{created_ids[:model_slug]}/#{created_ids[:record]}")
    end
    delete_if_present("/api/v3/setup/flow/#{created_ids[:flow]}") if created_ids[:flow]
    delete_if_present("/api/v3/setup/plain_webhook/#{created_ids[:webhook]}") if created_ids[:webhook]
    delete_if_present("/api/v3/setup/liquid_template/#{created_ids[:template]}") if created_ids[:template]
    delete_if_present("/api/v3/setup/json_data_type/#{created_ids[:data_type]}") if created_ids[:data_type]
  end
end
