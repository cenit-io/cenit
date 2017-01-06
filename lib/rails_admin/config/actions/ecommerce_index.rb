module RailsAdmin
  module Config
    module Actions
      class EcommerceIndex < RailsAdmin::Config::Actions::Base

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            ec_cat_id = 'ecommerce'
            shared_collection_config = RailsAdmin::Config.model(Setup::CrossSharedCollection)
            unless (filter_token = Cenit::Token.where('data.category_id': ec_cat_id).first)
              cat = Setup::Category.where(id: ec_cat_id).first || Setup::Category.new(title: 'eCommerce')
              message = "<span><em>#{shared_collection_config.label_plural}</em> with category <em>#{cat.title}</em></span>"
              filter_token = Cenit::Token.create(data: {
                criteria: Setup::CrossSharedCollection.where(category_ids: cat.id).selector,
                message: message,
                category_id: ec_cat_id
              })
            end
            redirect_to rails_admin.index_path(model_name: shared_collection_config.abstract_model.to_param, filter_token: filter_token.token)
          end
        end

        register_instance_option :link_icon do
          'fa fa-shopping-basket'
        end
      end
    end
  end
end
