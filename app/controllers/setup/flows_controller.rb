module Setup
  class FlowsController < Setup::BaseController
    before_action :find_flow, only: [:show, :update, :destroy]

    # GET /flows.json
    def index
      @flows = Setup::Flow.all
    end

    # GET /flows/1.json
    def show
    end

    # GET /flows/new.json
    def new
      @flow = Setup::Flow.new
      render json: @flow
    end

    # POST /flows.json
    def create
      @flow = Setup::Flow.new(permited_attributes)
      if @flow.save
        render json: @flow, status: :created, location: @flow
      else
        render json: @flow.errors, status: :unprocessable_entity
      end
    end

    # PUT /flows/1.json
    def update
      if @flow.update_attributes(params[:flow])
        head :no_content
      else
        render json: @flow.errors, status: :unprocessable_entity
      end
    end

    # DELETE /flows/1.json
    def destroy
      @flow.destroy
      head :no_content
    end
    
    protected
    def permited_attributes 
      params[:flow].permit(:name, :purpose, :active, :data_type_id, :connection_role_id, :webhook_id, :event_id)
    end
    
    def find_flow
      @flow = Setup::Flow..find_by(slug: params[:id])
    end
    
  end
end
