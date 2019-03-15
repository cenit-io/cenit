module Setup
  module TranslationCommon
    extend ActiveSupport::Concern

    include Setup::BulkableTask

    included do
      belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

      before_save do
        self.translator = Setup::Translator.where(id: message[:translator_id]).first if translator.blank?
      end
    end

    def run(message)
      if (translator = Setup::Translator.where(id: (translator_id = message[:translator_id])).first)
        unless message[:options].is_a?(Hash)
          begin
            message[:options] = self.class.parse_options(message[:options].to_s)
          rescue ::Exception => ex
            fail "transformation options #{ex.message}"
          end
        end
        begin
          send('translate_' + translator.type.to_s.downcase, message)
        rescue ::Exception => ex
          Setup::SystemNotification.create_from(ex, "Error executing translator '#{translator.custom_title}'")
          fail "Error executing translator '#{translator.custom_title}' (#{ex.message})"
        end
      else
        fail "Transformation with id #{translator_id} not found"
      end
    end

    module ClassMethods
      def parse_options(options)
        options = options.to_s.strip
        options = "{#{options}" unless options.start_with?('{')
        options = "#{options}}" unless options.ends_with?('}')
        ast =
          begin
            ::Parser::CurrentRuby.parse(options)
          rescue ::Exception
            nil
          end
        if ast && ast.type == :hash
          check_hash(ast)
          eval(options)
        else
          fail 'have not a Hash syntax'
        end
      end

      private

      def check_hash(ast)
        ast.children.each do |child|
          fail 'have not a valid options Hash format.' unless child.type == :pair
          unless [:sym, :str].include?(child.children[0].type)
            fail "contains a non valid key '#{child.children[0].location.expression.source}'"
          end
          check_value(child.children[1])
        end
      end

      def check_array(ast)
        ast.children.each { |child| check_value(child) }
      end

      def check_value(ast)
        if ast.type == :hash
          check_hash(ast)
        elsif ast.type == :array
          check_array(ast)
        else
          unless [:sym, :str, :int, :float, :true, :false, :nil].include?(ast.type)
            fail "contains a non valid value '#{ast.location.expression.source}'"
          end
        end
      end
    end
  end
end
