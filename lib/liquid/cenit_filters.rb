module Liquid
  module CenitFilters
    def hmac_sha256(input, operand)
      input.to_s.hmac_hex_sha256(operand.to_s)
    end
  end

  Template.register_filter(CenitFilters)
end
