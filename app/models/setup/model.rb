module Setup
  class Model
    include CenitScoped
    include SchemaHandler

    Setup::Models.exclude_actions_for self, :new, :update, :edit, :delete, :bulk_delete, :delete_all

    BuildInDataType.regist(self).including(:schema).referenced_by(:name)

    def self.to_include_in_models
      @to_include_in_models ||= [Mongoid::Document,
                                 Mongoid::Timestamps,
                                 Setup::SchemaModelAware,
                                 Setup::ClassAffectRelation,
                                 Mongoid::CenitExtension,
                                 EventLookup,
                                 AccountScoped,
                                 DynamicValidators,
                                 Edi::Formatter,
                                 Edi::Filler] #, RailsAdminDynamicCharts::Datetime]
    end

    field :title, type: String
    field :name, type: String

    field :activated, type: Boolean, default: false
    field :show_navigation_link, type: Boolean
    field :used_memory, type: BigDecimal, default: 0
    field :model_loaded, type: Boolean
    field :to_be_destroyed, type: Boolean

    has_many :events, class_name: Setup::Observer.to_s, dependent: :destroy, inverse_of: :data_type

    attr_readonly :name

    validates_presence_of :name

    scope :activated, -> { where(activated: true) }

    before_destroy do
      !(records_model.try(:delete_all) rescue true) || true
    end

    def validator
      nil
    end

    def library
      nil
    end

    def on_library_title
      if lib = library
        "#{lib.name} | #{title}"
      else
        title
      end
    end

    def subtype?
      false
    end

    def data_type_storage_collection_name
      Account.tenant_collection_name(data_type_name)
    end

    def data_type_collection_name
      data_type_storage_collection_name
    end

    def all_data_type_collections_names
      [data_type_collection_name]
    end

    def all_data_type_storage_collections_names
      [data_type_storage_collection_name]
    end

    def storage_size(scale=1)
      records_model.storage_size(scale)
    end

    def count
      records_model.count
    end

    def records_model
      (m = model) && m.is_a?(Class) ? m : @mongoff_model ||= create_mongoff_model
    end

    def model
      data_type_name.constantize rescue nil
    end

    def loaded?
      model ? true : false
    end

    def data_type_name
      "Dt#{self.id.to_s}"
    end

    def to_be_destroyed?
      to_be_destroyed
    end

    def load_model(options={})
      load_models(options)[:model]
    end

    def load_models(options={reload: false, reset_config: true})
      reload
      do_activate = options.delete(:activated) || activated
      report = {loaded: Set.new, errors: {}}
      begin
        model =
          if (do_shutdown = options[:reload]) || !loaded?
            merge_report(Model.shutdown(self, options), report) if do_shutdown
            do_load_model(report)
          else
            self.model
          end
      rescue Exception => ex
        #TODO Delete raise
        raise ex
        puts "ERROR: #{errors.add(:model_schema, ex.message).to_s}"
        report[:errors][self] = errors.full_messages
        Model.shutdown(self, options)
      end
      create_default_events
      if model
        reload
        report[:loaded] << (report[:model] = model)
        if self.used_memory != (model_used_memory = Cenit::Utility.memory_usage_of(model))
          self.used_memory = model_used_memory
        end
        report[:destroyed].delete_if { |m| m.to_s == model.to_s } if report[:destroyed]
        self.activated = do_activate if do_activate.present?
        self.model_loaded = true
      else
        self.used_memory = 0 unless self.used_memory == 0
        self.activated = false
        self.model_loaded = false
      end
      save unless new_record?
      report
    end

    def visible
      self.show_navigation_link
    end

    def navigation_label
      library && library.name
    end

    def create_default_events
      if model.is_a?(Class) && Setup::Observer.where(data_type: self).empty?
        Setup::Observer.create(data_type: self, triggers: '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}}')
        Setup::Observer.create(data_type: self, triggers: '{"updated_at":{"0":{"o":"_change","v":["","",""]}}}')
      end
    end

    def find_data_type(ref)
      (lib = library) && lib.find_data_type_by_name(ref)
    end

    def report_shutdown(report)
      deconstantize(data_type_name, report)
      unless report[:report_only]
        self.to_be_destroyed = true if report[:destroy]
        self.used_memory = 0
        self.model_loaded = false
        save unless new_record?
      end
      report
    end

    class << self
      def shutdown(data_types, options={})
        return {} unless data_types
        options[:reset_config] = options[:reset_config].nil? && !options[:report_only]
        raise Exception.new("Both options 'destroy' and 'report_only' is not allowed") if options[:destroy] && options[:report_only]
        data_types = [data_types] unless data_types.is_a?(Enumerable)
        data_type_ids = data_types.collect(& ->(data_type) { data_type.id.to_s })
        Model.any_in(id: data_type_ids).update_all(to_be_destroyed: true) if options[:destroy]
        report = options.reverse_merge!(destroyed: Set.new, affected: Set.new, reloaded: Set.new, errors: {})
        Model.any_in(id: data_type_ids).each { |data_type| data_type.report_shutdown(report) }
        puts "Report: #{report.to_s}"
        post_process_report(report)
        puts "Post processed report #{report}"
        unless options[:report_only]
          opts = options.reject { |key, _| key == :destroy }
          report[:destroyed].to_a.each do |model|
            model.data_type.report_shutdown(opts) unless data_type_ids.include?(model.data_type.id.to_s)
          end
          destroy_constant(report[:destroyed])
          puts 'Reloading affected models...' if report[:affected].present?
          destroyed_lately = []
          report[:affected].each do |model|
            data_type = model.data_type
            unless report[:errors][data_type] || report[:reloaded].detect { |m| m.to_s == model.to_s }
              begin
                if model.parent == Object && data_type.activated
                  puts "Reloading #{model.schema_name rescue model.to_s} -> #{model.to_s}"
                  model_report = data_type.load_models(reload: true, reset_config: false)
                  report[:reloaded] += model_report[:reloaded] + model_report[:loaded]
                  report[:destroyed] += model_report[:destroyed]
                  if loaded_model = model_report[:model]
                    report[:reloaded] << loaded_model
                  else
                    report[:destroyed] << model
                    report[:errors][data_type] = data_type.errors
                  end
                else
                  puts "Model #{model.schema_name rescue model.to_s} -> #{model.to_s} reload on parent reload!"
                end
              rescue Exception => ex
                raise ex
                puts "Error deconstantizing  #{model.schema_name rescue model.to_s}"
                destroyed_lately << model
              end
              puts "Model #{model.schema_name rescue model.to_s} -> #{model.to_s} reloaded!"
            end
          end
          report[:affected].clear
          destroy_constant(destroyed_lately)
          report[:destroyed].delete_if { |model| report[:reloaded].detect { |m| m.to_s == model.to_s } }
          puts "Final report #{report}"
          RailsAdmin::AbstractModel.update_model_config([], report[:destroyed], report[:reloaded]) if options[:reset_config]
        end
        report
      end

      private

      def destroy_constant(models)
        models = [models] unless models.is_a?(Enumerable)
        models = models.sort_by do |model|
          index = 0
          if model.is_a?(Class)
            parent = model.parent
            while !parent.eql?(Object)
              index = index - 1
              parent = parent.parent
            end
          end
          index
        end
        models.each do |model|
          puts "Decontantizing #{constant_name = model.model_access_name} -> #{model.schema_name rescue model.to_s}"
          constant_name = constant_name.split('::').last
          parent = model.is_a?(Class) ? model.parent : Object
          parent.send(:remove_const, constant_name) if parent.const_defined?(constant_name)
        end
      end

      def post_process_report(report)
        sets = Set.new
        report[:affected].each do |model|
          unless set = sets.detect { |set| set.include?(model) }
            set = collect_affected_from(model)
            set.instance_variable_set(:@__activated, set.detect { |m| !report[:destroyed].include?(m) && m.data_type.activated })
          end
          sets << set
          unless set.instance_variable_get(:@__activated)
            report[:destroyed] << model
            report[:affected].delete(model)
          end
        end
        to_destroy_also = Set.new
        to_scan = report[:destroyed].clone
        scanned = Set.new
        until to_scan.empty?
          to_scan.each do |model|
            model.affected_by.each do |m|
              unless set = sets.detect { |set| set.include?(m) }
                set = collect_affected_from(m)
                set.instance_variable_set(:@__activated, set.detect { |m| !report[:destroyed].include?(m) && m.data_type.activated })
              end
              sets << set
              unless set.instance_variable_get(:@__activated)
                to_destroy_also += set
              end
            end
          end
          scanned += to_scan
          to_scan = to_destroy_also - scanned
        end
        report[:destroyed] += to_destroy_also

        affected_children =[]
        report[:affected].each { |model| affected_children << model if ancestor_included(model, report[:affected]) }
        report[:affected].delete_if { |model| report[:destroyed].include?(model) || affected_children.include?(model) }

        report[:affected].to_a.each do |m|
          unless m.parent == Object && m.data_type.activated
            report[:affected].delete(m)
            report[:destroyed] << m
          end
        end
      end

      def ancestor_included(model, container)
        parent = model.parent
        while !parent.eql?(Object)
          return true if container.include?(parent)
          parent = parent.parent
        end
        false
      end

      def collect_affected_from(model, set = Set.new)
        return set if set.include?(model)
        set << model
        model.affected_models.each { |m| collect_affected_from(m, set) }
        set
      end
    end

    protected

    def do_load_model(report)
      raise NotImplementedError
    end

    def merge_report(report, in_to)
      in_to.deep_merge!(report) { |_, this_val, other_val| this_val + other_val }
    end

    def deconstantize(constant_name, report = {})
      report.reverse_merge!(:destroyed => Set.new, :affected => Set.new)
      if constant = constant_name.constantize rescue nil
        do_deconstantize(constant, report)
      end
      report
    end

    def do_deconstantize(constant, report, affected=nil)
      if constant.is_a?(Class)
        deconstantize_class(constant, report, affected)
      else
        deconstantize_mongoff_model(constant, report, affected)
      end
    end

    def preprocess_deconstantization(klass, report, affected)
      return [false, affected] if klass == Object
      affected = nil if report[:shutdown_all]
      if !affected && report[:affected].include?(klass)
        report[:affected].delete(klass)
        report[:destroyed] << klass
      end
      return [false, affected] if report[:destroyed].include?(klass) || report[:affected].include?(klass)
      parent = klass.parent
      affected = nil if report[:destroyed].include?(parent)
      [true, affected]
    end

    def deconstantize_mongoff_model(model, report={:destroyed => Set.new, :affected => Set.new}, affected=nil)
      continue, affected = preprocess_deconstantization(model, report, affected)
      return report unless continue
      puts "Reporting #{affected ? 'affected' : 'destroyed'} model #{model.to_s} -> #{model.schema_name rescue model.to_s}"
      (affected ? report[:affected] : report[:destroyed]) << model
      model.affected_models.each { |model| do_deconstantize(model, report, :affected) }
    end

    def deconstantize_class(klass, report={:destroyed => Set.new, :affected => Set.new}, affected=nil)
      continue, affected = preprocess_deconstantization(klass, report, affected)
      return report unless continue
      puts "Reporting #{affected ? 'affected' : 'destroyed'} class #{klass.to_s} -> #{klass.schema_name rescue klass.to_s}"
      (affected ? report[:affected] : report[:destroyed]) << klass
      klass.constants(false).each do |const_name|
        if klass.const_defined?(const_name, false)
          const = klass.const_get(const_name, false)
          do_deconstantize(const, report, affected)
        end
      end
      #[:embeds_one, :embeds_many, :embedded_in].each do |rk|
      [:embedded_in].each do |rk|
        begin
          klass.reflect_on_all_associations(rk).each do |r|
            unless report[:destroyed].include?(r.klass) || report[:affected].include?(r.klass)
              deconstantize_class(r.klass, report, :affected)
            end
          end
        rescue
        end
      end
      # relations affects if their are reflected back
      {[:embeds_one, :embeds_many] => [:embedded_in],
       [:belongs_to] => [:has_one, :has_many],
       [:has_one, :has_many] => [:belongs_to],
       [:has_and_belongs_to_many] => [:has_and_belongs_to_many]}.each do |rks, rkbacks|
        rks.each do |rk|
          klass.reflect_on_all_associations(rk).each do |r|
            rkbacks.each do |rkback|
              unless report[:destroyed].include?(r.klass) || report[:affected].include?(r.klass)
                deconstantize_class(r.klass, report, :affected) if r.klass.reflect_on_all_associations(rkback).detect { |r| r.klass.eql?(klass) }
              end
            end
          end
        end
      end
      klass.affected_models.each { |m| do_deconstantize(m, report, :affected) }
      deconstantize_class(klass.parent, report, affected) if affected
      report
    end

    def create_mongoff_model
      Mongoff::Model.for(data_type: self)
    end
  end
end