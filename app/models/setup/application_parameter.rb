module Setup
  class ApplicationParameter
    include CenitScoped

    BuildInDataType.regist(self)

    field :name, type: String
    field :type, type: String
    field :many, type: Boolean

    embedded_in :application, class_name: Setup::Application.to_s, inverse_of: :application_parameters

    validates_presence_of :name

    def type_enum
      %w(integer number boolean string) +
        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect { |r| r.name.to_s.singularize.to_title }
    end

    def schema
      sch =
        if type.blank?
          {}
        elsif %w(integer number boolean string).include?(type)
          {
            type: type
          }
        else
          {
            '$ref': Setup::Collection.reflect_on_association(type.to_s.downcase.gsub(' ', '_').pluralize).klass.to_s,
            referenced: true
          }
        end
      (many ? { type: 'array', items: sch } : sch).stringify_keys
    end
  end
end
