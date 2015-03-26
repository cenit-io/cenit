module Setup
  module Transformation
    class DoubleCurlyBracesTransform < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          source_hash = JSON.parse(options[:source].to_json)
          template_hash = JSON.parse(options[:transformation])
          do_template(template_hash, source_hash)
          options[:target].from_json(template_hash)
        end

        private

        def do_template(template_hash, source_hash)
          for_each_key_value_on(template_hash) do |key, value|
            if value.is_a?(String)
              new_value = nil
              tokens = value.split('{{')
              tokens.shift while tokens.first.empty?
              tokens.pop while tokens.last.empty?
              tokens.each do |token|
                if index = token.index('}}')
                  new_token = source_hash
                  token[0, index].split('.').each do |k|
                    next if new_token.nil? || new_token = new_token[k]
                  end
                  new_token =
                      if new_token.is_a?(Hash)
                        new_token.to_json
                      else
                        new_token.to_s
                      end if new_value || tokens.length > 1 || token.length > index + 2
                  new_value = new_value ? new_value.to_s + new_token : new_token
                  if token.length > index + 2
                    new_value += token.from(index + 2).gsub('}}', '')
                  end
                else
                  new_value = token
                end
              end
              template_hash[key] = new_value
            end
          end
          template_hash
        end

        def for_each_key_value_on(hash, &block)
          hash.each do |k, v|
            block.yield(k, v) if block
            for_each_key_value_on(v, &block) if v.is_a?(Hash)
          end
        end
      end
    end
  end
end