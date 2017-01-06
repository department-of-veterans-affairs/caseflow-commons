$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift File.expand_path("../../app/models/caseflow", __FILE__)
require "caseflow"
require "stats"


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

