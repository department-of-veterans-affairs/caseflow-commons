def get_session(req)
  session_cookie_name = Rails.application.config.session_options[:key]
  req.cookie_jar.encrypted[session_cookie_name] || {}
end

ip = Rails.env.production? ? IPSocket.getaddress(Socket.gethostname) : 'localhost'

log_tags = [:host, ip]

log_tags << lambda { |req| Time.now }

log_tags << lambda { |req|
  session = get_session(req)
  user = session["user"]
  ["id", "email"].map { | attr | user[attr] }.join(" ") if user
}

# don't mix worker and RAILS http logs
if !ENV["IS_WORKER"].blank?
  log_tags << "jobs-worker"
end

Rails.application.config.log_tags = log_tags

# log sidekiq to application logger (defaults to stdout)
Sidekiq::Logging.logger = Rails.logger if defined?(Sidekiq::Logging)
