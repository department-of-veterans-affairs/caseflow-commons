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
  # rubocop:disable all
  def self.sync!(config_file)
    features_from_cache = features

    features_from_cache.each do |feature_from_cache|
      # Hash from config file (example: {feature: "enable_all_feature", regional_offices: ["RO01"]})
      hash_from_file = config_file.select { |hash| hash[:feature] == feature_from_cache.to_s }[0]

      if hash_from_file.nil?
        disable!(feature_from_cache)
      else
        enable_all_key = hash_from_file.keys.select { |key| key == :enable_all }[0]
        users_key = hash_from_file.keys.select { |key| key == :users }[0]
        offices_key = hash_from_file.keys.select { |key| key == :regional_offices }[0]

        enable_all_value = hash_from_file[:enable_all] unless enable_all_key.nil?
        users_value = hash_from_file[:users] unless users_key.nil?
        offices_value = hash_from_file[:regional_offices] unless offices_key.nil?

        if enable_all_value
          enable!(feature_from_cache)
        else
          # Details in cache (example: {:users=>["Good", "Bad", "Ugly"], :regional_offices=>["TR"]})
          hash_from_cache = details_for(feature_from_cache)
          if hash_from_cache.empty?
            disable!(feature_from_cache)
            enable!(feature_from_cache, users: users_value) unless users_key.nil?
            enable!(feature_from_cache, regional_offices: offices_value) unless offices_key.nil?
          else
            users_key_cache = hash_from_cache.keys.select { |key| key == :users }[0]
            offices_key_cache = hash_from_cache.keys.select { |key| key == :regional_offices }[0]

            users_value_cache = hash_from_cache[:users] unless users_key_cache.nil?
            offices_value_cache = hash_from_cache[:regional_offices] unless offices_key_cache.nil?

            if users_key_cache
              if users_key
                disable!(feature_from_cache, users: users_value_cache - users_value)
              else
                disable!(feature_from_cache, users: users_key_cache)
              end
            end
            if offices_key_cache
              if offices_key
                disable!(feature_from_cache, regional_offices: offices_value_cache - offices_value)
              else
                disable!(feature_from_cache, regional_offices: offices_key_cache)
              end
            end
            enable!(feature_from_cache, users: users_value) unless users_key.nil?
            enable!(feature_from_cache, regional_offices: offices_value) unless offices_key.nil?
          end
        end
      end
    end

    # Enable features that were non-existed before
    features_from_file = config_file.map { |hash| hash.values[0] } - features_from_cache
    features_from_file.each do |feature|
      hash_from_file = config_file.select { |hash| hash[:feature] == feature.to_s }[0]
      hash_from_file.keys[1] == :enable_all ? enable!(feature) : enable!(feature, hash_from_file.keys[1] => hash_from_file.values[1])
    end
  end
  # rubocop:enable all

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
      return false unless users.present? && user

      downcased_users = users.map { |usr| usr.downcase.strip }
      downcased_user = user.css_id.downcase.strip

      downcased_users.include?(downcased_user)
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
  end
end
