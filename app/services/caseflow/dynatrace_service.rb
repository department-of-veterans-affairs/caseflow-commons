# frozen_string_literal: true

class ExternalApi::DynatraceService

  #      BASE_URL = ENV["DYNATRACE_URL"]
  #      API_TOKEN = ENV["DYNATRACE_TOKEN"]
  
  class << self
  
    def  increment(stat_name, tags: tags, by: by)
      #stuff
      # build request
      # request = HTTPI::Request.new(BASE_URL)
      # request.open_timeout = 300
      # request.read_timeout = 300
      # request.auth.ssl.ca_cert_file = ENV["SSL_CERT_FILE"]

      # build body
      # request.body = render json: {
      #   displayName: stat_name,
      #   description: "",
      #   unit: "Unspecified",
      #   tags: tags,
      #   }

      # HTTPI.post(request)
    end

    def gauge(stat_name, metric_value, tags: tags)
      #stuff
      # build request
      # request = HTTPI::Request.new(BASE_URL)
      # request.open_timeout = 300
      # request.read_timeout = 300
      # request.auth.ssl.ca_cert_file = ENV["SSL_CERT_FILE"]

      # # build body
      # request.body = render json: {
      #   displayName: stat_name,
      #   description: "",
      #   unit: "Unspecified",
      #   tags: tags,
      #   }

      # HTTPI.post(request)
    end

    def histogram(stat_name, metric_value, tags: tags)
      #stuff
      # build request
      # request = HTTPI::Request.new(BASE_URL)
      # request.open_timeout = 300
      # request.read_timeout = 300
      # request.auth.ssl.ca_cert_file = ENV["SSL_CERT_FILE"]

      # # build body
      # request.body = render json: {
      #   displayName: stat_name,
      #   description: "",
      #   unit: "Unspecified",
      #   tags: tags,
      #   }

      # HTTPI.post(request)
    end
  end
end