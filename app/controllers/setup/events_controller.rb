module Setup
  class EventsController < Setup::BaseController
    # GET /events.json
    def index
      @events = Setup::Event.all
      render json: @events
    end

    # GET /events/1.json
    def show
      @event = Setup::Event.find(params[:id])
      render json: @event
    end

    # GET /events/new.json
    def new
      @event = Setup::Event.new
      render json: @event
    end

    # POST /events.json
    def create
      @event = Setup::Event.new(permited_attributes)
      if @event.save
        render json: @event, status: :created, location: @event
      else
        render json: @event.errors, status: :unprocessable_entity
      end
    end

    # PUT /events/1.json
    def update
      @event = Setup::Event.find(params[:id])
      if @event.update_attributes(params[:event])
        head :no_content
      else
        render json: @event.errors, status: :unprocessable_entity
      end
    end

    # DELETE /events/1.json
    def destroy
      @event = Setup::Event.find(params[:id])
      @event.destroy
      head :no_content
    end
    
    protected
    def permited_attributes 
      params[:event].permit(:name, :triggers, :data_type_id)
    end  
    
  end
end
