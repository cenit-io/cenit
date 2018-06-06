module RailsAdmin
  ###
  # Features to embed swagger editor.
  module SwaggerHelper
    ###
    # Return swagger editor configuration.
    def swagger_config
      {
          # Analytics section is used for user tracking configurations. At the moment
          # only Google Analytics is supported.
          analytics: {
              google: {
                  # Put your Google Analytics ID here
                  id: 'UA-51231036-1'
              }
          },

          # Code generator endpoints s are used for generating servers and client
          # Swagger Editor will GET list of server and client generators and POST to
          # each `server` and `client` with Swagger document in body to download the
          # product of the code generator.
          codegen: {
              # Menu items are generated based on result of GET request to these
              # endpoint
              servers: '//generator.swagger.io/api/gen/servers',
              clients: '//generator.swagger.io/api/gen/clients',

              # For each item in menu item, Swagger Editor will make calls to these
              # endpoint to download the generated code accordingly
              server: '//generator.swagger.io/api/gen/servers/{language}',
              client: '//generator.swagger.io/api/gen/clients/{language}'
          },


          #  Disables Code Generators
          disableCodeGen: false,

          # Folder that example files are located
          # Note that this string will be used in between two other url segments
          # so you always need the trailing and leading slashes
          examplesFolder: "/swagger-editor/spec-files/",

          # Ace editor options. This object will overload existing editor options.
          # See all possible options here: http://ace.c9.ionav=api&api=ace
          editorOptions: {
              "theme": "ace/theme/atom_dark"
          },

          # List of example files to show to user to pick from. The URL to fetch each
          # example is a combination of `examplesFolder` and file name
          exampleFiles: [],

          # Keywords for auto-complete are generated from a JavaScript object.
          # See keyword-map.js for object format
          autocompleteExtension: {},

          # Use a back-end for storing the document instead of browser local storage
          useBackendForStorage: true,

          # Change how many milliseconds after the last keypress the editor should
          # respond to change.
          keyPressDebounceTime: 200,

          # The timeout for throttling backend calls
          backendThrottle: 200,

          # URL of the Back-end for storing swagger document. Editor will PUT and GET
          # to this URL to **Save** and **Read** the Swagger document
          backendEndpoint: "/#{params[:model_name]}/#{params[:id]}/swagger/spec",

          # When using a back-end, editor by default PUTs JSON document for Saving.
          # Enable this to use YAML instead
          useYamlBackend: true,

          # Disables File menu which includes New, Open Example and Import commands
          disableFileMenu: true,

          # When it's enabled:
          #  * Editor will append `brandingCssClass` class to body tag
          #  * Editor will include branding templates at
          #      app/templates/branding-left.html and
          #      app/templates/branding-left.html
          #       to it's header
          headerBranding: false,

          # Enables Try Operation functionality
          enableTryIt: true,

          # When `headerBranding` is enabled, this will be appended to body tag
          brandingCssClass: "",

          # Disables the overlay introduction panel
          disableNewUserIntro: false,

          # When Editor imports a file from a URL, it will prepend this URL to make
          # it possible to import contents that are not allowed to be loaded from a
          # different origin. If you're hosting your own editor, please replace this
          importProxyUrl: "https://cors-it.herokuapp.com/?url=",

          # Use this base path for resolving JSON Pointers ($ref).
          # This value should be a valid URL.
          #
          # Example: http://example.com/swaggers
          #
          # More info: https://github.com/swagger-api/swagger-editor/issues/977#issuecomment-232254578
          pointerResolutionBasePath: nil
      }
    end

    ###
    # Returns api specification.
    def swagger_get_spec
      render text: @object.specification, content_type: 'text/yaml'
    end

    ###
    # Update api specification.
    def swagger_set_spec
      spec = request.body.read

      @object.update(specification: spec) unless @object.specification == spec

      if @object.errors.present?
        render text: @object.errors.full_messages.to_sentence, status: :bad_request
      else
        render text: 'Success!'
      end
    end

  end
end