# frozen_string_literal: true

require "benchmark"
require "datadog/statsd"

# see https://dropwizard.github.io/metrics/3.1.0/getting-started/ for abstractions on metric types
module Caseflow
  class MetricsService
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    # :reek:LongParameterList
    @statsd = Datadog::Statsd.new
  
    def self.increment_counter(metric_group:, metric_name:, app_name:, attrs: {}, by: 1)
      tags = get_tags(app_name, attrs)
      stat_name = get_stat_name(metric_group, metric_name)
  
      @statsd.increment(stat_name, tags: tags, by: by)
      # DynatraceService.increment(stat_name, tags: tags, by: by)
    end
  
    def self.record_runtime(metric_group:, app_name:, start_time: Time.zone.now)
      metric_name = "runtime"
      job_duration_seconds = Time.zone.now - start_time
  
      emit_gauge(
        app_name: app_name,
        metric_group: metric_group,
        metric_name: metric_name,
        metric_value: job_duration_seconds
      )
    end
  
    def self.emit_gauge(metric_group:, metric_name:, metric_value:, app_name:, attrs: {})
      tags = get_tags(app_name, attrs)
      stat_name = get_stat_name(metric_group, metric_name)
  
      @statsd.gauge(stat_name, metric_value, tags: tags)
      # DynatraceService.gauge(stat_name, metric_value, tags: tags)
    end
  
    # :nocov:
    def self.histogram(metric_group:, metric_name:, metric_value:, app_name:, attrs: {})
      tags = get_tags(app_name, attrs)
      stat_name = get_stat_name(metric_group, metric_name)
  
      @statsd.histogram(stat_name, metric_value, tags: tags)
      # DynatraceService.histogram(stat_name, metric_value, tags: tags)
    end
    # :nocov:
  
    #these function exist in Caseflow
  
    private_class_method def self.get_stat_name(metric_group, metric_name)
      "dsva-appeals.#{metric_group}.#{metric_name}"
    end
  
    private_class_method def self.get_tags(app_name, attrs)
      extra_tags = attrs.reduce([]) do |tags, (key, val)|
        tags + ["#{key}:#{val}"]
      end
    [
      "app:#{app_name}",
      "env:#{Rails.current_env}"
    ] + extra_tags
    end

    # metric service class methods
    def self.record(description, service: nil, name: "unknown", caller: nil)
      return_value = nil
      app = RequestStore[:application] || "other"
      service ||= app
      uuid = SecureRandom.uuid
      metric_name = "request_latency"
      sent_to = [[Caseflow::MetricAttributes::LOG_SYSTEMS[:rails_console]]]
      sent_to_info = nil

      start = Time.zone.now
      Rails.logger.info("STARTED #{description}")
      stopwatch = Benchmark.measure do
        return_value = yield
      end
      stopped = Time.zone.now

      if service
        latency = stopwatch.real
        sent_to_info = {
          metric_group: "service",
          metric_name: metric_name,
          metric_value: latency,
          app_name: app,
          attrs: {
            service: service,
            endpoint: name,
            uuid: uuid
          }
        }
        MetricsService.emit_gauge(sent_to_info)

        sent_to << Caseflow::MetricAttributes::LOG_SYSTEMS[:datadog]
        sent_to << Caseflow::MetricAttributes::LOG_SYSTEMS[:dynatrace]

      end

      Rails.logger.info("FINISHED #{description}: #{stopwatch}")

      metric_params = {
        name: metric_name,
        message: description,
        type: Caseflow::MetricAttributes::METRIC_TYPES[:performance],
        product: service,
        attrs: {
          service: service,
          endpoint: name
        },
        sent_to: sent_to,
        sent_to_info: sent_to_info,
        start: start,
        end: stopped,
        duration: stopwatch.total * 1000 # values is in seconds and we want milliseconds
      }
      store_record_metric(uuid, metric_params, caller)

      return_value
    rescue StandardError => error
      Rails.logger.error("#{error.message}\n#{error.backtrace.join("\n")}")
      Raven.capture_exception(error, extra: { type: "request_error", service: service, name: name, app: app })

      increment_metrics_counter("request_error", service, name, app) if service

      metric_params = {
        name: "error",
        message: error.message,
        type: Caseflow::MetricAttributes::METRIC_TYPES[:error],
        product: "",
        attrs: {
          service: "",
          endpoint: ""
        },
        sent_to: [[Caseflow::MetricAttributes::LOG_SYSTEMS[:rails_console]]],
        sent_to_info: "",
        start: "Time not recorded",
        end: "Time not recorded",
        duration: "Time not recorded"
      }

      store_record_metric(uuid, metric_params, caller)

      # Re-raise the same error. We don't want to interfere at all in normal error handling.
      # This is just to capture the metric.
      raise
    ensure
      increment_metrics_counter("request_attempt", service, name, app) if service
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    private_class_method def self.increment_metrics_counter(metric_name, service, endpoint_name, app_name)
      MetricsService.increment_counter(
        metric_group: "service",
        metric_name: metric_name,
        app_name: app_name,
        attrs: {
          service: service,
          endpoint: endpoint_name
        }
      )
    end
    # :reek:ControlParameter
    def self.store_record_metric(uuid, params, caller)
      # Metrics are only stored for certain users within the Caseflow application.
      return nil if !(FeatureToggle.enabled?(:metrics_monitoring, user: RequestStore[:current_user])) or params[:app_name] == "efolder"
      name = "caseflow.server.metric.#{params[:name]&.downcase&.gsub(/::/, '.')}"
      params = {
        uuid: uuid,
        name: name,
        message: params[:message],
        type: params[:type],
        product: params[:product],
        metric_attributes: params[:attrs],
        sent_to: params[:sent_to],
        sent_to_info: params[:sent_to_info],
        start: params[:start],
        end: params[:end],
        duration: params[:duration]
      }

      metric = Metric.create_metric(caller || self, params, RequestStore[:current_user])
      failed_metric_info = metric&.errors.inspect
      Rails.logger.info("Failed to create metric #{failed_metric_info}") unless metric&.valid?
    end
  end
end