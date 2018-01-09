# frozen_string_literal: true
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift File.expand_path("../../app/models/caseflow", __FILE__)
$LOAD_PATH.unshift File.expand_path("../../app/services", __FILE__)
require "redis"
require "redis-namespace"
require "caseflow"
require "caseflow/s3_service"
require "stats"
require "feature_toggle"
require "functions"

class FakeCache
  # make it a singleton so there is only one instance shared between the tests and application code
  include Singleton
  def data
    @data ||= {}
  end

  def write(key, value)
    data[key] = value
  end

  def read(key)
    data[key]
  end

  def clear
    @data = {}
  end
end

class FakeApplication
  include Singleton

  def secrets
    @secrets ||= OpenStruct.new(redis_url_cache: "redis://localhost:6379/0/cache/")
  end
end
