module Setup
  class DataTypesController < Setup::BaseController
    before_action :find_data_type, only: [:show, :update, :destroy]

    # GET /data_types.json
    def index
      @data_types = Setup::DataType.all
    end

    # GET /data_types/1.json
    def show
    end

    # GET /data_types/new.json
    def new
      @data_type = Setup::DataType.new
      render json: @data_type
    end

    # POST /data_types.json
    def create
      @data_type = Setup::DataType.new(permited_attributes)
      if @data_type.save
        render :show, status: :created
      else
        render json: @data_type.errors, status: :unprocessable_entity
      end
    end

    # PUT /data_types/1.json
    def update
      if @data_type.update_attributes(params[:data_type])
        head :no_content
      else
        render json: @data_type.errors, status: :unprocessable_entity
      end
    end

    # DELETE /data_types/1.json
    def destroy
      @data_type.destroy
      head :no_content
    end
    
    protected
    def permited_attributes 
      params[:data_type].permit(:name, :model_schema, :sample_data)
    end
    
    def find_data_type
      @data_type = Setup::DataType.find(params[:id])
    end    
    
  end
end
