require "xmlrpc/parser"
require "xmlrpc/create"

class CenitXMLRPC
  class << self
    def method_call(name, *params)
      create_obj = XMLRPC::Create.new
      create_obj.methodCall(name, *params)
    end

    def parse_method_response(data)
      parse_obj = XMLRPC::XMLParser::REXMLStreamParser.new
      parse_obj.parseMethodResponse(data)
    end
  end
end
