module Api::V1
  class ApiController < ApplicationController
    before_action :save_request_data, :authorize
    before_action :find_item, only: [:show, :destroy]
    rescue_from Exception, :with => :exception_handler
    respond_to :json

    PRESENTATION_KEY = { '_id' => 'id' }.freeze

    def index
      @items = klass.all
      render json: @items.map { |item| { @model => attr_presentation(item.attributes) } }
    end

    def show
      render json: { @model => attr_presentation(@item.attributes)  }
    end

    def push
      result = {}
      @payload.each do |root, message|
        items = {}
        message.is_a?(Array) ? message.each { |e| items[e] = process_message(root,e) } : items[message] = process_message(root,message)
        result[root] = items
      end
      result.delete_if { |_, value| value.compact.blank? }
      broken = {}
      result.each { |root, v| broken[root] = v.map { |e, obj| Cenit::Utility.save(obj) ? next : { error_messages: obj.errors.full_messages, item: e } } }
      broken.delete_if { |_, value| value.compact.blank? }
      response = {}
      if result.present?
        result.each { |root, v| response[root.pluralize] = v.map { |_, obj| true }.flatten.count }
        response.merge(errors: broken) if broken.present?
        render json: response
      else
        render json: broken, status: :unprocessable_entity
      end
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
        render json: { status: "item not found" }
      end
    end

    def get_model(model)
      model = model.singularize
      "Setup::#{model.camelize}".constantize
    rescue
      Setup::DataType.where(name: model.camelize).first.model
    end

    def klass
      "Setup::#{@model.camelize}".constantize rescue get_model(@model)
    end

    def process_message(root, message)
      if klass = get_model(root)
        klass.data_type.new_from_json(message)
      end
    end

    def attr_presentation(items)
      items.is_a?(Array) ? items.map { |e| remove_mogo_id(e) }.flatten : remove_mogo_id(items)
    end

    def remove_mogo_id(items)
      return { id: items.to_s } if items.is_a?(BSON::ObjectId)
      return items unless items.is_a?(Enumerable)
      PRESENTATION_KEY.each { |key, value| items.merge!(value => items.delete(key)) }
      items.delete_if { |key, value| value.blank? }
      items.each { |key, value| items[key] = (key == 'id' ? attr_presentation(value.to_s) : attr_presentation(value)) }
      items
    end

    def save_request_data
      @request_id = request.uuid
      if (@webhook_body = request.body.read).present?
        @payload = JSON.parse(@webhook_body).with_indifferent_access
      end
      @lib = params[:lib]
      @model = params[:model]
    end
  end
end
