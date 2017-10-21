module RailsAdmin
  module Config
    module Actions
      HistoryShow.class_eval do

        register_instance_option :listing? do
          bindings[:controller].instance_variable_get(:@objects)
        end

        register_instance_option :controller do
          proc do
            Thread.current["[cenit][#{HistoryTracker}]:persistence-options"] = { model: @object.class }
            @model_config = RailsAdmin::Config.model(HistoryTracker)
            @context_abstract_model = @model_config.abstract_model

            if (track_id = params[:track_id])
              unless (@history_track = @object.history_tracks.where(id: track_id).first)
                flash[:error] = "History track with ID #{track_id} not found"
              end
            end

            unless @history_track
              @objects = list_entries(@model_config, :history, @object.history_tracks_scope)
              render :index
            end
          end
        end

        def url_options(opts)
          opts = super
          if (object = bindings[:object]).is_a?(HistoryTracker)
            opts[:model_name] = RailsAdmin::Config.model(bindings[:abstract_model].model.persistence_model).abstract_model.to_param
            if (trackable = object.trackable)
              opts[:id] = trackable.id
              opts[:track_id] = object.id
            end
          end
          opts
        end

        register_instance_option :i18n_key do
          if bindings[:object].is_a?(HistoryTracker)
            :show
          else
            key
          end
        end

        register_instance_option :link_icon do
          if bindings[:object].is_a?(HistoryTracker)
            'icon-info-sign'
          else
            'icon-book'
          end
        end
      end
    end
  end
end
