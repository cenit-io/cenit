module RailsAdmin

  class MongoffModelConfig < RailsAdmin::Config::Model

    include ThreadAware

    def initialize(mongoff_entity)
      super
      @model = @abstract_model.model
      @parent = self

      titles = Set.new
      titles.add(nil)
      groups = {}
      @model.properties.each do |property|
        property = @abstract_model.property_or_association(property)
        type = property.type
        if property.is_a?(RailsAdmin::MongoffAssociation)
          type = (type.to_s + '_association').to_sym
        elsif (enumeration = property.enum)
          type = :enum
        end
        configure property.name, type do
          visible { property.visible? }
          read_only do
            bindings[:object].new_record? ? false : property.read_only?
          end
          if titles.include?(title = property.title)
            title = property.name.to_s.to_title
          end
          titles.add(title)
          label { title }
          filterable { property.filterable? }
          required { property.required? }
          queryable { property.queryable? }
          valid_length { {} }
          if enumeration
            enum { enumeration }
            filter_enum { enumeration }
          end
          if (description = property.description)
            description = "#{property.required? ? 'Required' : 'Optional'}. #{description}".html_safe
            help { description }
          end
          unless (g = property.group.to_s.gsub(/ +/, '_').underscore.to_sym).blank?
            group g
            groups[g] = property.group.to_s
          end
          if property.is_a?(RailsAdmin::MongoffAssociation)
            # associated_collection_cache_all true
            pretty_value do
              v = bindings[:view]
              action = v.instance_variable_get(:@action)
              if (action.is_a?(RailsAdmin::Config::Actions::Show) || action.is_a?(RailsAdmin::Config::Actions::RemoteSharedCollection)) && !v.instance_variable_get(:@showing)
                amc = RailsAdmin.config(association.klass)
              else
                amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config # perf optimization for non-polymorphic associations
              end
              am = amc.abstract_model
              if action.is_a?(RailsAdmin::Config::Actions::Show) && !v.instance_variable_get(:@showing)
                values = [value].flatten.select(&:present?)
                fields = amc.list.with(controller: bindings[:controller], view: v, object: amc.abstract_model.model.new).visible_fields
                unless fields.length == 1 && values.length == 1
                  v.instance_variable_set(:@showing, true)
                end
                table = <<-HTML
                    <table class="table table-condensed table-striped">
                      <thead>
                        <tr>
                          #{fields.collect { |field| "<th class=\"#{field.css_class} #{field.type_css_class}\">#{field.label}</th>" }.join}
                          <th class="last shrink"></th>
                        <tr>
                      </thead>
                      <tbody>
                  #{values.collect do |associated|
                  can_see = !am.embedded_in?(bindings[:controller].instance_variable_get(:@abstract_model)) && (show_action = v.action(:show, am, associated))
                  '<tr class="script_row">' +
                    fields.collect do |field|
                      field.bind(object: associated, view: v)
                      "<td class=\"#{field.css_class} #{field.type_css_class}\" title=\"#{v.strip_tags(associated.to_s)}\">#{field.pretty_value}</td>"
                    end.join +
                    '<td class="last links"><ul class="inline list-inline">' +
                    if can_see
                      v.menu_for(:member, amc.abstract_model, associated, true)
                    else
                      ''
                    end +
                    '</ul></td>' +
                    '</tr>'
                end.join}
                      </tbody>
                    </table>
                HTML
                v.instance_variable_set(:@showing, false)
                table.html_safe
              else
                max_associated_to_show = 3
                count_associated = [value].flatten.count
                associated_links = [value].flatten.select(&:present?).collect do |associated|
                  wording = associated.send(amc.object_label_method)
                  can_see = !am.embedded_in?(bindings[:controller].instance_variable_get(:@abstract_model)) && (show_action = v.action(:show, am, associated))
                  can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : wording
                end.to(max_associated_to_show-1).to_sentence.html_safe
                if (count_associated > max_associated_to_show)
                  associated_links = associated_links+ " and #{count_associated - max_associated_to_show} more".html_safe
                end
                associated_links
              end
            end
            if (f = property.schema['filter'])
              filter f
            end
          end
        end
      end
      if @model.is_a?(Mongoff::GridFs::FileModel)
        configure :data, :mongoff_file_upload do
          required { bindings[:object].new_record? }
        end
        configure :length do
          label 'Size'
          pretty_value do #TODO Factorize these code in custom rails admin field type
            if (objects = bindings[:controller].instance_variable_get(:@objects))
              unless (max = bindings[:controller].instance_variable_get(:@max_length))
                bindings[:controller].instance_variable_set(:@max_length, max = objects.collect { |storage| storage.length }.reject(&:nil?).max)
              end
              (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].length }).html_safe
            else
              bindings[:view].number_to_human_size(value)
            end
          end
        end
        edit do
          field :_id do
            visible do
              (o = bindings[:object]) &&
                (o = o.class.data_type) &&
                (o = o.schema) &&
                (o = o['properties']['_id']) &&
                o.key?('type')
            end
            help 'Required'
          end
          field :data
          field :metadata
        end
        list do
          field :_id
          field :filename
          field :contentType
          field :uploadDate
          field :aliases
          field :metadata
          field :length
        end
        show do
          field :_id
          field :filename
          field :contentType
          field :uploadDate
          field :aliases
          field :metadata
          field :length
          field :md5
        end
      else
        edit do
          parent.target.properties.each do |property|
            next if (property == '_id' && !parent.target.property_schema('_id').key?('type')) ||
              Mongoff::Model[:base_schema]['properties'].key?(property)
            field property.to_sym
          end
        end
      end

      navigation_label { target.data_type.namespace }

      navigation_icon { target.schema['icon'] }

      object_label_method do
        @object_label_method ||=
          if target.labeled?
            :to_s
          else
            Config.label_methods.detect { |method| target.property?(method) } || :to_s
          end
      end

      groups.each do |key, name|
        group key do
          label name
        end
      end
    end

    def dashboard_group_path
      if target.data_type.is_a?(Setup::JsonDataType)
        %w(data objects)
      else
        %w(data files)
      end
    end

    def parent
      self
    end

    def target
      @model
    end

    def excluded?
      false
    end

    def label
      contextualized_label
    end

    def label_plural
      contextualized_label_plural
    end

    def contextualized_label(context = nil)
      target.label(context)
    end

    def contextualized_label_plural(context = nil)
      contextualized_label(context).to_plural
    end

    def root
      self
    end

    def visible?
      true
    end

    class << self

      def new(mongoff_entity)
        mongoff_entity = RailsAdmin::MongoffAbstractModel.abstract_model_for(mongoff_entity)
        current_thread_cache[mongoff_entity.to_s] ||= super(mongoff_entity)
      end
    end
  end
end