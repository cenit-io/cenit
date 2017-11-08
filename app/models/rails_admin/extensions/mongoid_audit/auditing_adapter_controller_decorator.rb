module RailsAdmin
  module Extensions
    module MongoidAudit
      AuditingAdapter.class_eval do

        def version_class_for(object)
          @version_class.with(object.class.mongoid_root_class)
        end

        def version_class_with(abstract_model)
          @version_class.with(abstract_model.model.mongoid_root_class)
        end

        def listing_for_model_or_object(model, object, query, sort, sort_reverse, all, page, per_page)
          if sort.present?
            sort = COLUMN_MAPPING[sort.to_sym]
          else
            sort = :created_at
            sort_reverse = 'true'
          end
          model_name = model.model.name
          if object
            versions = version_class_for(object).where('association_chain.name' => model.model_name, 'association_chain.id' => object.id)
          else
            versions = version_class_with(model).where('association_chain.name' => model_name)
          end
          versions = versions.order_by([sort, sort_reverse == 'true' ? :desc : :asc])
          unless all
            page = 1 if page.nil?
            versions = versions.send(Kaminari.config.page_method_name, page).per(per_page)
          end
          versions.map { |version| VersionProxy.new(version) }
        end
      end
    end
  end
end
