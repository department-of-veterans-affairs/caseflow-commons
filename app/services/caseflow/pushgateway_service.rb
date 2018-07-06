# frozen_string_literal: true

require "net/http"
require "uri"

# Interface to pushgateway service running in a local docker container (sidecar)
module Caseflow
  class PushgatewayService
    def initialize
      @health_uri = URI("http://127.0.0.1:9091/-/healthy")
    end

    def healthy?
      # see: https://github.com/prometheus/pushgateway/pull/135
      res = Net::HTTP.get_response(@health_uri)
      res.is_a?(Net::HTTPSuccess)
    rescue StandardError
      false
    end
  end
end
