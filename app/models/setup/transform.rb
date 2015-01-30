module Setup
  class Transform
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable
    
    belongs_to :data_type, class_name: Setup::DataType.name
    belongs_to :schema_validation, class_name: Setup::Schema.name
    
    has_many :flows, class_name: Setup::Flow.name, inverse_of: :transforms

    field :name, type: String
    field :transformation, type: String
    field :style, type: String

    validates_presence_of :transformation, :style

    def style_enum
      %W(double_curly_braces xslt json.rabl xml.rabl xml.builder html.erb )
    end
    
    def run(object, options = {})
      options = options.merge(object: object, transformation: transformation)
      case style
      when /double_curly_braces/  
        Setup::Transformation::JsonTransform.run(options)
      when /xslt/
        Setup::Transformation::XsltTransform.run(options)
      else
        Setup::Transformation::ActionViewTransform.run(options.merge(style: style))
      end
    end
    
  end
end