module Setup
  class CollectionsController < Setup::BaseController
    before_action :find_template, only: [:show, :update, :destroy]

    def index
      @tenplates = Setup::Collection.all
    end

    def show
    end

    def new
      @collection = Setup::Collection.new
      render json: @collection
    end

    def create	  
      @collection = Setup::Collection.new(permited_attributes)
      if @collection.save
        render :show, status: :created
      else
        render json: @collection.errors, status: :unprocessable_entity
      end
    end

    def update
      if @collection.update_attributes(params[:collection])
        head :no_content
      else
        render json: @collection.errors, status: :unprocessable_entity
      end
    end

    def destroy
      @collection.destroy
      head :no_content
    end
    
    protected
    def permited_attributes
      params[:collection].permit(:name, :library_attributes , :connection_role_attributes, :weebhooks_attributes, :flows_attributes )
    end  
    
    def find_template
      @collection = Setup::Collection.find(params[:id])
    end  
    
  end
end
