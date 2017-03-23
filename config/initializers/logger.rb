def get_session(req)
  session_cookie_name = Rails.application.config.session_options[:key]
  req.cookie_jar.encrypted[session_cookie_name] || {}
end

ip = Rails.env.production? ? IPSocket.getaddress(Socket.gethostname) : 'localhost'

log_tags = [:host, :uuid, ip]

log_tags << lambda { |req|
  session = get_session(req)
  user = session["user"]
  ["id", "email"].map { | attr | user[attr] }.join(" ") if user
}

# don't mix worker and RAILS http logs
if !ENV["IS_WORKER"].blank?
  log_tags << "jobs-worker"
end

class LoggerWithTimestamp < ActiveSupport::Logger
  def add(severity, message, progname, &block)
    tagged(Time.now) {
      super(severity, message, progname, &block)
    }
  end
end

unless Rails.env.test?
  Rails.application.config.log_tags = log_tags
  logger = ActiveSupport::TaggedLogging.new(LoggerWithTimestamp.new(STDOUT))
  Rails.logger = logger
end

# log sidekiq to application logger (defaults to stdout)
Sidekiq::Logging.logger = Rails.logger if defined?(Sidekiq::Logging)
