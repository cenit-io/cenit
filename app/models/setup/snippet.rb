
module Setup
  class Snippet < ReqRejValidator
    include SharedEditable
    include NamespaceNamed

    build_in_data_type.referenced_by(:namespace, :name)

    field :description, type: String
    field :type, type: Symbol, default: :javascript
    field :code, type: String

    has_and_belongs_to_many :tags, class_name: Setup::Tag.to_s, inverse_of: nil
    validates_presence_of :type

    before_save :validates_configuration

    def validates_configuration
      requires(:name, :code)
      errors.add(:type, 'is not valid') unless type_enum.has_value?(type)

      case type
        when :auto
      #    # use extension for explicit type
      #    # extension = name.split('.')[-1]
          language = LanguageSniffer.detect(name, :content => code).language
          if language && type_enum.has_key?(language.name)
            type_ = type_enum[language.name]
          else
            type_ = 'text'
          end
          self.type = type_
      end


      errors.blank?
    end

    def type_enum
      {
          'Auto detect': :auto,
          'Plain text': :text,
          'AppleScript': :applescript,
          'BoxNote': :boxnote,
          'C': :c,
          'C#': :csharp,
          'C++': :cpp,
          'CSS': :css,
          'CSV': :csv,
          'Clojure': :clojure,
          'CoffeeScript': :coffeescript,
          'Cold Fusion': :cfm,
          'Crystal': :crystal,
          'Cypher': :cypher,
          'D': :d,
          'Dart': :dart,
          'Diff': :diff,
          'Docker': :dockerfile,
          'Erlang': :erlang,
          'F#': :fsharp,
          'Fortran': :fortran,
          'Gherkin': :gherkin,
          'Go': :go,
          'Groovy': :groovy,
          'HTML': :html,
          'Handlebars': :handlebars,
          'Haskell': :haskell,
          'Haxe': :haxe,
          'Java': :java,
          'Javascript/JSON': :javascript,
          'Julia': :julia,
          'Kotlin': :kotlin,
          'LaTeX/sTeX': :latex,
          'Lisp': :lisp,
          'Lua': :lua,
          'MatLab': :matlab,
          'MUMPS': :mumps,
          'Markdown (raw)': :markdown,
          'OCaml': :ocaml,
          'Objective-C': :objc,
          'PHP': :php,
          'Pascal': :pascal,
          'Perl': :perl,
          'Pig': :pig,
          'Post': :post,
          'Powershell': :powershell,
          'Puppet': :puppet,
          'Python': :python,
          'R': :r,
          'Ruby': :ruby,
          'Rust': :rust,
          'SQL': :sql,
          'Sass': :sass,
          'Scala': :scala,
          'Scheme': :scheme,
          'Shell': :shell,
          'SmallTalk': :smalltalk,
          'Swift': :swift,
          'TSV': :tsv,
          'VB.net': :vb,
          'VBScript': :vbscript,
          'Velocity': :velocity,
          'Verilog': :verilog,
          'XML': :xml,
          'YAML': :yaml
      }
    end
  end
end
