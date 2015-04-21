module Setup
  class ApiController < ApplicationController
    include Cenit::StrongParameters
    
    respond_to :json
    before_action :authorize
    
    before_action :find_model
    before_action :find_item, only: [:show, :update, :destroy]

    def index
      @items = get_model.all
      render json: @items.map { |item| { @model => attributes(item) } }
    end

    def show
      render json: { @model => attributes(@item) }
    end

    def create
      @item = get_model.new(permited_attributes)
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
      user = User.find_by(key: key) if key && token

      if user && Devise.secure_compare(user.token, token) && user.has_role?(:admin)
        Account.current = user.account
        return true
      end

      render json: 'Unauthorized!', status: :unprocessable_entity 
      return false
    end

    def permited_attributes
      p = JSON.parse (JSON.parse params.to_json).with_indifferent_access.keys.first
      parameters = ActionController::Parameters.new(p[@model])
      parameters.permit(send "permitted_#{@model}_attributes")
    end
    
    def find_model
      @model = params[:model]
    end

    def find_item
      @item = get_model.where(id: params[:id]).first
      unless @item.present?
        render json: {status: "item not found"}
      end
    end
    
    def get_model
      "Setup::#{@model.camelize}".constantize
    end  

    def attributes(item)
      id = item.attributes.delete('_id').to_s
      item.attributes.merge('id' => id)
    end  

  end
end
