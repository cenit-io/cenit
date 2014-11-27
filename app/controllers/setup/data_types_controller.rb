module Setup
  class DataTypesController < Setup::BaseController
    # GET /data_types.json
    def index
      @data_types = Setup::DataType.all
      render json: @data_types
    end

    # GET /data_types/1.json
    def show
      @data_type = Setup::DataType.find(params[:id])
      render json: @data_type
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
        render json: @data_type, status: :created, location: @data_type
      else
        render json: @data_type.errors, status: :unprocessable_entity
      end
    end

    # PUT /data_types/1.json
    def update
      @data_type = Setup::DataType.find(params[:id])
      if @data_type.update_attributes(params[:data_type])
        head :no_content
      else
        render json: @data_type.errors, status: :unprocessable_entity
      end
    end

    # DELETE /data_types/1.json
    def destroy
      @data_type = Setup::DataType.find(params[:id])
      @data_type.destroy
      head :no_content
    end
    
    protected
    def permited_attributes 
      params[:data_type].permit(:name, :schema, :sample_data)
    end  
    
  end
end
