module Setup
  class ConnectionsController < Setup::BaseController
    before_action :find_connection, only: [:show, :update, :destroy]

    # GET /connections.json
    def index
      @connections = Setup::Connection.all
    end

    # GET /connections/1.json
    def show
    end

    # GET /connections/new.json
    def new
      @connection = Setup::Connection.new
      render json: @connection, only: [:name, :slug, :url]
    end

    # POST /connections.json
    def create	  
      @connection = Setup::Connection.new(permited_attributes)
      if @connection.save
        render json: @connection, status: :created, location: @connection
      else
        render json: @connection.errors, status: :unprocessable_entity
      end
    end

    # PUT /connections/1.json
    def update
      if @connection.update_attributes(params[:connection])
        head :no_content
      else
        render json: @connection.errors, status: :unprocessable_entity
      end
    end

    # DELETE /connections/1.json
    def destroy
      @connection.destroy
      head :no_content
    end
    
    protected
    def permited_attributes
      params[:connection].permit(:name, :slug, :key, :url, :connection_roles_attributes)
    end  
    
    def find_connection
      @connection = Setup::Connection.find_by(slug: params[:id])
    end  
    
  end
end
