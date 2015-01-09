module Setup
  class WebhooksController < Setup::BaseController
    before_action :find_webhook, only: [:show, :update, :destroy]

    # GET /webhooks.json
    def index
      @webhooks = Setup::Webhook.all
    end

    # GET /webhooks/1.json
    def show
    end

    # GET /webhooks/new.json
    def new
      @webhook = Setup::Webhook.new
      render json: @webhook
    end

    # POST /webhooks.json
    def create
      @webhook = Setup::Webhook.new(permited_attributes)
      if @webhook.save
        render :show, status: :created
      else
        render json: @webhook.errors, status: :unprocessable_entity
      end
    end

    # PUT /webhooks/1.json
    def update
      if @webhook.update_attributes(params[:webhook])
        head :no_content
      else
        render json: @webhook.errors, status: :unprocessable_entity
      end
    end

    # DELETE /webhooks/1.json
    def destroy
      @webhook.destroy
      head :no_content
    end

    protected
    def permited_attributes 
      params[:webhook].permit(:id, :name, :path, :purpose, 
        data_type_attributes: [:id, :name], 
        data_type_response_attributes: [:id, :name], 
        connection_roles_attributes: [:id, :name, connections_attributes: [:id, :name, :url]])
    end

    def find_webhook
      @webhook = Setup::Webhook.find(params[:id])
    end

  end
end
