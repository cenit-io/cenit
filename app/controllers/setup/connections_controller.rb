module Setup
  class ConnectionsController < ApplicationController
    before_filter :authorize
    
    # GET /connections
    # GET /connections.json
    def index
      @connections = Setup::Connection.all

      respond_to do |format|
        format.html # index.html.erb
        format.json { render json: @connections }
      end
    end

    # GET /connections/1
    # GET /connections/1.json
    def show
      @connection = Setup::Connection.find(params[:id])

      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @connection }
      end
    end

    # GET /connections/new
    # GET /connections/new.json
    def new
      @connection = Setup::Connection.new

      respond_to do |format|
        format.html # new.html.erb
        format.json { render json: @connection }
      end
    end

    # GET /connections/1/edit
    def edit
      @connection = Setup::Connection.find(params[:id])
    end

    # POST /connections
    # POST /connections.json
    def create
      @connection = Setup::Connection.new(params[:connection])

      respond_to do |format|
        if @connection.save
          format.html { redirect_to @connection, notice: 'Connection was successfully created.' }
          format.json { render json: @connection, status: :created, location: @connection }
        else
          format.html { render action: "new" }
          format.json { render json: @connection.errors, status: :unprocessable_entity }
        end
      end
    end

    # PUT /connections/1
    # PUT /connections/1.json
    def update
      @connection = Setup::Connection.find(params[:id])

      respond_to do |format|
        if @connection.update_attributes(params[:connection])
          format.html { redirect_to @connection, notice: 'Connection was successfully updated.' }
          format.json { head :no_content }
        else
          format.html { render action: "edit" }
          format.json { render json: @connection.errors, status: :unprocessable_entity }
        end
      end
    end

    # DELETE /connections/1
    # DELETE /connections/1.json
    def destroy
      @connection = Setup::Connection.find(params[:id])
      @connection.destroy

      respond_to do |format|
        format.html { redirect_to connections_url }
        format.json { head :no_content }
      end
    end
    
    protected
    def authorize
      # we are using token authentication via header.
      key = request.headers['X-Hub-Store']
      token = request.headers['X-Hub-Access-Token']
      connection = Setup::Connection.unscoped.find_by(key: key)

      if connection && Devise.secure_compare(connection.authentication_token, token)
        #TODO: Check if 'X-Hub-Timestamp' belong to a small time window around Time.now
        return true
      else
        Account.current = connection.account
        response_handler = Handler.new(@message)
        responder = response_handler.response('Unauthorized!', 401)
        render json: responder, root: false, status: responder.code
        return false
      end
    end
  end
end
