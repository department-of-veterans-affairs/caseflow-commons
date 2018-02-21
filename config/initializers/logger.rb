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

Rails.application.config.log_tags = log_tags
output = Rails.env.test? ? File.join(Rails.root, "log", "test.log") : STDOUT
logger = ActiveSupport::TaggedLogging.new(LoggerWithTimestamp.new(output))

# Rails has a lot of loggers
# This line causes double logging in development
Rails.logger = logger unless Rails.env.development?

# TODO Rails5Upgrade - Clean this up after upgrading
ActiveSupport::Dependencies.logger = logger if ActiveSupport::Dependencies.respond_to? :logger=


Rails.cache.logger = ActiveSupport::TaggedLogging.new(LoggerWithTimestamp.new(File.join(Rails.root, "log", "cache.log")))
ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.logger = logger
end
ActiveSupport.on_load(:action_controller) do
  ActionController::Base.logger = logger
end
ActiveSupport.on_load(:action_mailer) do
  ActionMailer::Base.logger = logger
end
ActiveSupport.on_load(:action_view) do
  ActionView::Base.logger = logger
end

# log sidekiq to application logger (defaults to stdout)
Sidekiq::Logging.logger = logger if defined?(Sidekiq::Logging)
