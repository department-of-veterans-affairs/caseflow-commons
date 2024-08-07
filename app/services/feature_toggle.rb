class FeatureToggle
  # Keeps track of all enabled features
  FEATURE_LIST_KEY = :feature_list_key

  def self.features
    client.smembers(FEATURE_LIST_KEY).map(&:to_sym)
  end

  # Method to enable a feature globally or limit acces
  # to a set of individual users or regional offices
  # Examples:
  # FeatureToggle.enable!(:foo)
  # FeatureToggle.enable!(:bar, regional_offices: ["RO01", "RO02"])
  # FeatureToggle.enable!(:bar, users: ["CSS_ID_1", "CSS_ID_2"])
  def self.enable!(feature, regional_offices: nil, users: nil)
    # redis method: sadd (add item to a set)
    client.sadd FEATURE_LIST_KEY, feature unless features.include?(feature)

    if regional_offices.present?
      enable(feature: feature,
             key: :regional_offices,
             value: regional_offices)
    end

    enable(feature: feature, key: :users, value: users) if users.present?

    true
  end

  # Method to disable a feature globally or for a specfic set of regional offices
  # Examples:
  # FeatureToggle.disable!(:foo)
  # FeatureToggle.disable!(:bar, regional_offices: ["RO01", "RO02"])
  # FeatureToggle.disable!(:bar, users: ["CSS_ID_1", "CSS_ID_2"])
  def self.disable!(feature, regional_offices: nil, users: nil)
    unless regional_offices || users
      remove_feature(feature)
      return true
    end

    disable(feature: feature,
            key: :regional_offices,
            value: regional_offices)

    disable(feature: feature,
            key: :users,
            value: users)

    # disable the feature completely if users and regional_offices become empty
    # to avoid accidentally enabling the feature globally
    remove_feature(feature) if feature_enabled_hash(feature).empty?
    true
  end

  # Method to check if a given feature is enabled for a user
  def self.enabled?(feature, user: nil)
    return false unless features.include?(feature)

    data = feature_enabled_hash(feature)
    regional_offices = data[:regional_offices]
    users = data[:users]

    enabled = false
    enabled = true if enabled_globally?(users: users, regional_offices: regional_offices)
    enabled = true if enabled_for_user?(users: users, user: user)
    enabled = true if enabled_for_regional_office?(regional_offices: regional_offices, user: user)

    enabled
  end

  # Returns a hash result for a given feature
  def self.details_for(feature)
    feature_enabled_hash(feature) if features.include?(feature)
  end

  # Set this to customize the redis namespace to prevent collisions
  def self.cache_namespace=(namespace)
    @cache_namespace = namespace
    @client = nil
  end

  def self.client
    # Use separate Redis namespace for test to avoid conflicts between test and dev environments
    @cache_namespace ||= Rails.env.test? ? :feature_toggle_test : :feature_toggle
    @client ||= Redis::Namespace.new(@cache_namespace, redis: redis)
  end

  def self.redis
    @redis ||= Redis.new(url: Rails.application.secrets.redis_url_cache)
  end

  # Example of config_file:
  # [
  #   {
  #     feature: "enable_all_feature",
  #     enable_all: true
  #   },
  #   {
  #     feature: "enable_users",
  #     users: ["VHAISADJURIN", "VHAISAPROKOA", "VHAISWSTEWAA"]
  #   },
  #   {
  #     feature: "enable_regional_offices",
  #     users: ["CSS_ID_1"],
  #     regional_offices: ["RO01"]
  #   }
  # ]
  def self.sync!(config_file_string)
    config_hash = validate_config(config_file_string)
    existing_features = features
    client.multi do
      features_from_file = []
      config_hash.each do |feature_hash|
        feature = feature_hash["feature"]
        features_from_file.push(feature)
        client.sadd FEATURE_LIST_KEY, feature
        data = {}
        data[:users] = feature_hash["users"] if feature_hash.key?("users")
        data[:regional_offices] = feature_hash["regional_offices"] if feature_hash.key?("regional_offices")
        set_data(feature, data)
      end
      existing_features.each { |feature| remove_feature(feature) unless features_from_file.include?(feature.to_s) }
    end
  end

  class << self
    private

    # If we do not have any users or regional office restrictions
    # then the feature is enabled *globally* and we accept *all* users
    def enabled_globally?(users:, regional_offices:)
      users.nil? && regional_offices.nil?
    end

    # If users key is set, check if the feature
    # is enabled for the user's css_id.
    # Since CSS usernames are not case sensitive,
    # our check is not case sensitive either.
    def enabled_for_user?(users:, user:)
      if users.to_s != "PEXIP" || user.to_s != "WEBEX"
        return false unless users.present? && user

        downcased_users = users.map { |usr| usr.downcase.strip }
        downcased_user = user.css_id.downcase.strip

        downcased_users.include?(downcased_user)
      end
    end

    # if regional_offices key is set, check if the feature
    # is enabled for the user's ro
    def enabled_for_regional_office?(regional_offices:, user:)
      regional_offices.present? && user && regional_offices.include?(user.regional_office)
    end

    def enable(feature:, key:, value:)
      data = feature_enabled_hash(feature)

      # Remove nil or duplicate values before saving
      data[key] = ((data[key] || []) + value).compact.uniq

      # Delete empty keys
      data.delete(key) if data[key].empty?

      set_data(feature, data)
    end

    def disable(feature:, key:, value:)
      return unless value

      data = feature_enabled_hash(feature)
      return unless data[key]

      data[key] = data[key] - value

      # Delete empty keys
      data.delete(key) if data[key].empty?

      set_data(feature, data)
    end

    def feature_enabled_hash(feature)
      data = client.get(feature)
      data && JSON.parse(data).symbolize_keys || {}
    end

    def remove_feature(feature)
      client.multi do
        # redis method: srem (remove item from a set)
        client.srem FEATURE_LIST_KEY, feature
        client.del feature
      end
    end

    def set_data(feature, data)
      client.set(feature, data.to_json)
    end

    def validate_config(config)
      config_hash = YAML.safe_load(config)
      config_hash.each do |feature_hash|
        validate_all(feature_hash)
        validate_feature(feature_hash)
        validate_enable_all(feature_hash["enable_all"]) if feature_hash.key?("enable_all")
        validate_users_and_offices("users", feature_hash["users"]) if feature_hash.key?("users")
        validate_users_and_offices("regional_offices", feature_hash["regional_offices"]) if feature_hash.key?("regional_offices")
      end
      config_hash
    end

    def validate_all(feature_hash)
      fail "Unknown key found in config object" unless (feature_hash.keys - %w[feature enable_all users regional_offices]).empty?
      fail "Ambiguous input" unless feature_hash.keys.include?("enable_all") ^
                                    (feature_hash.keys.include?("users") || feature_hash.keys.include?("regional_offices"))
      fail "Missing values in config object" if feature_hash.value?(nil)
    end

    def validate_feature(feature_hash)
      fail "Missing feature key in config object" unless feature_hash.keys.include?("feature")
      fail "Feature value should be a string" unless feature_hash["feature"].is_a? String
      fail "Empty string in feature" if feature_hash["feature"].empty?
    end

    def validate_enable_all(value)
      fail "enable_all value has to be true" unless value.is_a? TrueClass
    end

    def validate_users_and_offices(key, value)
      fail "#{key} value should be an array" unless value.is_a? Array
      fail "Empty array for #{key}" if value.empty?
      fail "#{key} values have to be strings" if value.any? { |x| !x.is_a? String }
      fail "Empty string in #{key}" if value.any?(&:empty?)
    end
  end
end
