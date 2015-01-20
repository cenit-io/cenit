module Setup
  class ConnectionRolesController < Setup::BaseController
    before_action :find_connection_role, only: [:show, :update, :destroy]

    # GET /connection_roles.json
    def index
      @connection_roles = Setup::ConnectionRole.all
    end

    # GET /connection_roles/1.json
    def show
    end

    # GET /connection_roles/new.json
    def new
      @connection_role = Setup::ConnectionRole.new
      render json: @connection_role.except(:account_id)
    end

    # POST /connection_roles.json
    def create
      @connection_role = Setup::ConnectionRole.new(permited_attributes)
      if @connection_role.save
        render json: @connection_role, status: :created, location: @connection_role
      else
        render json: @connection_role.errors, status: :unprocessable_entity
      end
    end

    # PUT /connection_roles/1.json
    def update
      if @connection_role.update_attributes(params[:connection_role])
        head :no_content
      else
        render json: @connection_role.errors, status: :unprocessable_entity
      end
    end

    # DELETE /connection_roles/1.json
    def destroy
      @connection_role.destroy
      head :no_content
    end
    
    protected
    def permited_attributes
      params[:connection_role].permit(:id, :name, 
        webhooks_attributes: [ :id, :name, :path, :purpose], 
        connections_attributes: [:id, :name, :url] )
    end  
    
    def find_connection_role
      @connection_role = Setup::ConnectionRole.find(params[:id])
    end

  end
end
