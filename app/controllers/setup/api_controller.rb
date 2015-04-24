module Setup
  class ApiController < ApplicationController
    include Cenit::StrongParameters
    before_action :save_request_data, :authorize
    # rescue_from Exception, :with => :exception_handler

    before_action :find_item, only: [:show, :update, :destroy]

    respond_to :json

    def index
      @items = klass.all
      render json: @items.map { |item| { @model => attributes(item) } }
    end

    def show
      render json: { @model => attributes(@item) }
    end

    def create
      @item = klass.new(permited_attributes)
      if @item.save
        render json: { @model => attributes(@item) }
      else
        render json: @item.errors, status: :unprocessable_entity
      end
    end

    def update
      if @item.update_attributes(permited_attributes)
        render json: { @model => attributes(@item) }
      else
        render json: item.errors, status: :unprocessable_entity
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
      # exception_handler = Handler.new(@message)
      # responder = exception_handler.response(exception.message, 500)
      # responder.backtrace = exception.backtrace.to_s
      # render json: responder, root: false, status: responder.code
      # return false
    end

    def permited_attributes
      parameters = ActionController::Parameters.new(@payload[@model])
      parameters.permit(send "permitted_#{@model}_attributes")
    end

    def find_item
      @item = klass.where(id: params[:id]).first
      unless @item.present?
        render json: {status: "item not found"}
      end
    end
    
    def klass
      "Setup::#{@model.camelize}".constantize
    end  

    def attributes(item)
      id = item.attributes.delete('_id').to_s
      item.attributes.merge('id' => id)
    end
    
    def save_request_data
      @model = params[:model]
      if (@webhook_body = request.body.read).present?
        @payload = JSON.parse(@webhook_body).with_indifferent_access
      end      
    end

  end
end
