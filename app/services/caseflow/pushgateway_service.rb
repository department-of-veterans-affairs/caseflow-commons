# frozen_string_literal: true

require 'net/http'
require 'uri'

# Interface to pushgateway service running in a local docker container (sidecar)
module Caseflow
  class PushgatewayService
    def initialize()
      @health_uri = URI('http://127.0.0.1:9091/-/healthy')
    end

    def is_healthy?
      # see: https://github.com/prometheus/pushgateway/pull/135
      begin
        res = Net::HTTP.get_response(@health_uri)
        healthy = res.is_a?(Net::HTTPSuccess)
        if not healthy
          logger.error "pushgateway sidecar health check failed: #{res.body}"
        end
        healthy
      rescue StandardError => e
        logger.error "pushgateway sidecar health check failed: #{e.message}\n#{e.backtrace.join("\n")}"
        false
      end
    end
  end
end