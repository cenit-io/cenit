module Setup
  class ApplicationParameter
    include CenitScoped

    BuildInDataType.regist(self)

    field :name, type: String
    field :type, type: String
    field :many, type: Boolean
    field :group, type: String
    field :description, type: String

    embedded_in :application, class_name: Setup::Application.to_s, inverse_of: :application_parameters

    validates_uniqueness_of :name
    validates_format_of :name, with: /\A[a-z]([a-z]|_|\d)*\Z/

    def type_enum
      %w(integer number boolean string) +
        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect { |r| r.name.to_s.singularize.to_title }
    end

    def group_enum
      (application && application.application_parameters.collect(&:group).uniq.select(&:present?)) || []
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
            '$ref': Setup::Collection.reflect_on_association(type.to_s.downcase.gsub(' ', '_').pluralize).klass.to_s
          }
        end.stringify_keys
      sch = (many ? { type: 'array', items: sch } : sch)
      sch[:referenced] = true unless %w(integer number boolean string).include?(type)
      sch[:group] = group if group.present?
      sch[:description] = description if description.present?
      sch.stringify_keys
    end
  end
end
