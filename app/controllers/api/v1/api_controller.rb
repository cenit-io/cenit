module Api::V1
  class ApiController < ApplicationController
    before_action :save_request_data, :authorize
    before_action :find_item, only: [:show, :update, :destroy]
    rescue_from Exception, :with => :exception_handler
    respond_to :json
    
    PRESENTATION_KEY = { '_id' => 'id'}.freeze

    def index
      @items = klass.all
      render json: @items.map { |item| { @model => attributes(item) } }
    end

    def show
      render json: { @model => attributes(@item) }
    end

    def push
      result = {}
      @payload.each do |root, message|
        items = {}
        message.is_a?(Array) ? message.each { |e| items[e] = process_message(root,e) } : items[message] = process_message(root,message)
        result[root] = items
      end
      result.delete_if { |key, value| value.compact.blank? }
      broken = {}
      result.each { |root, v| broken[root] = v.map { |e, obj| obj.save ? next : { error_messages: obj.errors.full_messages, item: e } } }
      broken.delete_if { |key, value| value.compact.blank? }
      response = {}
      if result.present? && broken.blank?
        result.each { |root, v| response[root.pluralize] = v.map { |_, obj| attributes(obj.attributes) }.flatten }
        render json: response
      else
        result.each { |root, v| v.each { |_, obj| obj.destroy } }
        render json: broken, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy
      head :no_content
    end

    protected

    def authorize
      # we are using token authentication via header.
      key = request.headers['X-User-Access-Key']
      token = request.headers['X-User-Access-Token']
      user = User.where(key: key).first if key && token
      if user && Devise.secure_compare(user.token, token) && user.has_role?(:admin)
        Account.current = user.account
        return true
      end
      render json: 'Unauthorized!', status: :unprocessable_entity 
      return false
    end
    
    def exception_handler(exception)
      responder = Cenit::Responder.new(@request_id, @webhook_body, 500)
      responder.backtrace = exception.backtrace.to_s
      render json: responder, root: false, status: responder.code
      return false
    end

    def find_item
      @model = params[:model]
      @item = klass.where(id: params[:id]).first
      unless @item.present?
        render json: { status: "item not found" }
      end
    end

    def klass
      "Setup::#{@model.camelize}".constantize
    end

    def process_message(root, message)
      "Setup::#{root.singularize.camelize}".constantize.data_type.new_from_json(message.to_json)
    end

    def attributes(items)
      items.is_a?(Array) ? items.map { |e| remove_mogo_id(e) }.flatten : remove_mogo_id(items)
    end

    def remove_mogo_id(items)
      return items.to_s if items.is_a?(BSON::ObjectId)
      return items unless items.is_a?(Enumerable)
      PRESENTATION_KEY.each { |key, value| items.merge!(value => items.delete(key)) }
      items.delete_if { |key, value| value.blank? }
      items.each { |key, value| items[key] = attributes(value) }
      items
    end

    def save_request_data
      @request_id = request.uuid
      if (@webhook_body = request.body.read).present?
        @payload = JSON.parse(@webhook_body).with_indifferent_access
      end
    end
  end
end
