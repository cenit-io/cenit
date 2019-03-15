module HerokuClient
  class Client

    class << self

      def post(url, options)
        HTTMultiParty.post(url, options)
      end

      def get(url, options)
        HTTMultiParty.get(url, options)
      end

      def client_collection_name
        ENV['HEROKU_COLLECTION_NAME'] || 'cenit_heroku_client'
      end

      def refresh_token
        token = nil
        url = "#{self.url}/oauth/token"

        body = {
            'grant_type'=> 'refresh_token',
            'refresh_token'=> ENV['HEROKU_REFRESH_TOKEN'],
            'client_scret'=> ENV['HEROKU_CLIENT_SECRET']
        }.to_json
        opts = {body: body}

        response = post(url, opts)

        if response.code == 201
          rc = JSON.parse(response.body)
          token = rc['access_token']
          expire = Time.now + rc['expires_in'] - 300
          Mongoid.default_client[client_collection_name].drop
          Mongoid.default_client[client_collection_name].insert({token: token, expire: expire})
        end

        token
      end

      def get_token
        doc = Mongoid.default_client[client_collection_name].find.first

        if doc && (doc[:expire] > Time.now)
          @token = doc[:token]
        else
          @token = ENV['HEROKU_TOKEN'] || refresh_token
        end

        @token
      end

      def get_url
        @url ||= 'https://api.heroku.com'
      end

      def get_headers
        @headers ||= {
            'Accept'=> "application/vnd.heroku+json; version=3",
            'Content-Type'=> "application/json",
            'Authorization'=> "Bearer #{get_token}"
        }
      end

    end

  end

  class App

    attr_reader :name

    def initialize(app_name)
      @name = app_name
    end

    class << self
      def url
        @url ||= "#{Client.get_url}/apps"
      end

      def create(name)
        opts = {
          headers: Client.get_headers,
          body: {
            name: name,
            region: 'us'
          }.to_json
        }

        response = Client.post(url, opts)
        if response.code == 201
          new(name)
        else
          nil
        end
      end
    end

    def add_addon(plan)
      url = "#{App.url}/#{name}/addons"
      opts = {
        headers: Client.get_headers,
        body: {
          plan: plan
        }.to_json
      }

      response = Client.post(url, opts)
      rc = response.code == 201
    end

    def get_variable(var_name)
      url = "#{App.url}/#{name}/config-vars"
      opts = {
          headers: Client.get_headers
      }
      response = Client.get(url, opts)
      rc = {}
      if response.code == 200
        rc = JSON.parse(response.body)
      end
      rc[var_name]
    end

  end
end