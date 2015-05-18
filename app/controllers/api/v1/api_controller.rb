module Api::V1
  class ApiController < ApplicationController
    before_action :save_request_data, :authorize
    before_action :find_item, only: [:show, :destroy]
    rescue_from Exception, :with => :exception_handler
    respond_to :json

    PRESENTATION_KEY = {'_id' => 'id'}.freeze

    def index
      @items = klass.all
      render json: @items.map { |item| {((model = (hash = item.to_hash(including: :_id)).delete('_type')) ? model.downcase : @model) => hash} }
    end

    def show
      render json: { @model => @item.to_hash }
    end

    def push
      response =
        {
          success: success_report = Hash.new { |h, k| h[k] = [] },
          errors: broken_report = Hash.new { |h, k| h[k] = [] }
        }
      payload =
        case request.content_type
        when 'application/json'
          JSONPayload
        when 'application/xml'
          XMLPayload
        else
          BasicPayload
        end.new(@webhook_body)
      payload.each do |root, message|
        if data_type = get_data_type(root)
          message = [message] unless message.is_a?(Array)
          message.each do |item|
            if (record = data_type.send(payload.create_method, payload.process_item(item, data_type))).errors.blank?
              success_report[root.pluralize] << record.to_json(only: :id, including_discards: true)
            else
              broken_report[root] << {errors: record.errors.full_messages, item: item}
            end
          end
        else
          broken_report[root] = 'no model found'
        end
      end
      response.delete(:success) if success_report.blank?
      response.delete(:errors) if broken_report.blank?
      render json: response
    end

    def destroy
      @item.destroy
      head :no_content
    end

    protected

    def authorize
      key = request.headers['X-User-Access-Key']
      token = request.headers['X-User-Access-Token']
      user = User.where(key: key).first if key && token
      if user && Devise.secure_compare(user.token, token) && user.has_role?(:admin)
        Account.current = user.account
        return true
      end

      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']
      unless Account.set_current_with_connection(key, token)
        responder = Cenit::Responder.new(@request_id, @webhook_body, 401)
        render json: responder, root: false, status: responder.code
        return false
      end
      true
    end

    def exception_handler(exception)
      responder = Cenit::Responder.new(@request_id, @webhook_body, 500)
      responder.backtrace = exception.backtrace.to_s
      render json: responder, root: false, status: responder.code
      return false
    end

    def find_item
      @item = klass.where(id: params[:id]).first
      unless @item.present?
        render json: {status: 'item not found'}
      end
    end

    def get_data_type(root)
      root = root.singularize.camelize
      @data_types[root] ||= Setup::BuildInDataType["Setup::#{root}"] || Setup::Model.where(name: root).first
    end

    def get_model(root)
      if data_type = get_data_type(root)
        data_type.records_model
      else
        nil
      end
    end

    def klass
      get_model(@model)
    end

    def save_request_data
      @data_types ||= {}
      @request_id = request.uuid
      @webhook_body = request.body.read
      @model = params[:model]
    end

    private

    attr_reader :webhook_body

    class BasicPayload

      attr_reader :create_method

      def initialize(payload = nil, create_method = :create_from)
        @payload = payload
        @create_method = create_method || :create_from
      end

      def each(&block)
      end

      def process_item(item, data_type)

      end
    end

    class JSONPayload < BasicPayload
      def initialize(webhook_body)
        super(JSON.parse(webhook_body), :create_from_json)
      end

      def each(&block)
        @payload.each { |root, message| block.call(root, message) } if block
      end

      def process_item(item, data_type)
        data_type.is_a?(Setup::FileDataType) ? item.to_json : item
      end
    end

    class XMLPayload < BasicPayload
      def initialize(webhook_body)
        super(Nokogiri::XML::DocumentFragment.parse(webhook_body), :create_from_xml)
      end

      def each(&block)
        if roots = @payload.element_children
          roots.each do |root|
            if elements = root.element_children
              elements.each { |e| block.call(root.name, e) }
            end
          end
        end if block
      end

      def process_item(item, data_type)
        data_type.is_a?(Setup::FileDataType) ? item.to_xml : item
      end
    end
  end
end
