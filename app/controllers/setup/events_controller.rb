module Setup
  class EventsController < Setup::BaseController
    before_action :find_event, only: [:show, :update, :destroy]

    # GET /events.json
    def index
      @events = Setup::Event.all
    end

    # GET /events/1.json
    def show
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
        render :show, status: :created
      else
        render json: @event.errors, status: :unprocessable_entity
      end
    end

    # PUT /events/1.json
    def update
      if @event.update_attributes(params[:event])
        head :no_content
      else
        render json: @event.errors, status: :unprocessable_entity
      end
    end

    # DELETE /events/1.json
    def destroy
      @event.destroy
      head :no_content
    end

    protected
    def permited_attributes 
      params[:event].permit(:name, :triggers, :data_type_id)
    end

    def find_event
      @event = Setup::Event.find(params[:id])
    end

  end
end
