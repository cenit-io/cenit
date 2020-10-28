module Setup
  module DataIterator
    extend ActiveSupport::Concern

    def decompress_content?
      message[:decompress_content]
    end

    def each_entry(&block)
      state.clear if state[:done]
      if decompress_content?
        begin
          Zip::InputStream.open(StringIO.new(data.read)) do |zis|
            next_entry_index = state[:next_entry_index] || 0
            i = -1
            entry = true
            data = nil
            entry_name = nil
            while entry && i < next_entry_index
              i += 1
              next unless (entry = zis.get_next_entry)
              entry_name = entry.name
              if i == next_entry_index && (data = entry.get_input_stream.read).blank?
                next_entry_index += 1
              end
            end
            if data.present?
              block.call(entry_name, data)
              state[:processed] = (state[:processed] || 0) + 1
              state[:next_entry_index] = next_entry_index + 1
              run_again
            else
              type =
                if (processed = state[:processed])
                  :notice
                else
                  processed = 0
                  :warning
                end
              notify(message: "#{processed} entries processed", type: type)
              state[:done] = true
            end
          end
        rescue Exception => ex
          state[:done] = true
          raise "Zip file format error: #{ex.message}"
        end
      else
        block.call(data.path.split('/').last, data.read)
        state[:done] = true
      end if block
    end
  end
end
