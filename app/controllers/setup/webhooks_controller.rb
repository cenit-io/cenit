module Setup
  class WebhooksController < Setup::BaseController
    # GET /webhooks.json
    def index
      @webhooks = Setup::Webhook.all
      render json: @webhooks
    end

    # GET /webhooks/1.json
    def show
      @webhook = Setup::Webhook.find(params[:id])
      render json: @webhook
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
        render json: @webhook, status: :created, location: @webhook
      else
        render json: @webhook.errors, status: :unprocessable_entity
      end
    end

    # PUT /webhooks/1.json
    def update
      @webhook = Setup::Webhook.find(params[:id])
      if @webhook.update_attributes(params[:webhook])
        head :no_content
      else
        render json: @webhook.errors, status: :unprocessable_entity
      end
    end

    # DELETE /webhooks/1.json
    def destroy
      @webhook = Setup::Webhook.find(params[:id])
      @webhook.destroy
      head :no_content
    end
    
    protected
    def permited_attributes 
      params[:webhook].permit(:name, :path, :purpose, :data_type_id, :connection_id)
    end  
    
  end
end
