module Unsplash
  class Connection
    include HTTParty

    DEFAULT_VERSION  = "v1"
    DEFAULT_API_BASE_URI   = "http://api.unsplash.com"
    DEFAULT_OAUTH_BASE_URI = "http://www.unsplash.com"

    def initialize(options = {})
      @application_id     = Unsplash.configuration.application_id
      @application_secret = Unsplash.configuration.application_secret
      @api_version        = options.fetch(:version, DEFAULT_VERSION)
      @api_base_uri       = options.fetch(:api_base_uri, DEFAULT_API_BASE_URI)
      
      oauth_base_uri     = options.fetch(:oauth_base_uri, DEFAULT_OAUTH_BASE_URI)
      @oauth = ::OAuth2::Client.new(@application_id, @application_secret, site: oauth_base_uri)

      Unsplash::Connection.base_uri @api_base_uri
    end

    def authorization_url(requested_scopes)
      @oauth.auth_code.authorize_url(redirect_uri: Unsplash.configuration.application_redirect_uri,
                                     scope:        requested_scopes.join(" "))
    end

    def authorize!(auth_code)
      @oauth_token = @oauth.auth_code.get_token(auth_code, redirect_uri: Unsplash.configuration.application_redirect_uri)
      # TODO check if it succeeded
    end


    def get(path, params = {})
      request :get, path, params
    end

    def put(path, params)
      request :put, path, params
    end

    private

    def request(verb, path, params = {})
      raise ArgumentError.new "Invalid http verb #{verb}" if ![:get, :post, :put].include?(verb)

      headers = {
        "Accept-Version" => @api_version
        # Anything else? User agent?
      }

      response = if @oauth_token
        @oauth_token = @oauth_token.refresh_token if @oauth_token.expired?
        @oauth_token.public_send(verb,  @api_base_uri + path, params: params, headers: headers)
      else

        # http.public_send(verb) do |req|
        #   req.url path, params
        #   req.headers.merge! headers.merge(public_auth_header)
        # end
        
        self.class.public_send verb, path, query: params, headers: public_auth_header

      end

      status_code = response.respond_to?(:status) ? response.status : response.code

      if !(200..299).include?(status_code)
        body = JSON.parse(response.body)
        msg = body["error"] || body["errors"].join(" ")
        raise Unsplash::Error.new msg
      end

      response
    end

    def public_auth_header
      { "Authorization" => "Client-ID #{@application_id}" }
    end
  end


end