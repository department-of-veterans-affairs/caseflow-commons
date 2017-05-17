# frozen_string_literal: true

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

  def self.client
    # Use separate Redis namespace for test to avoid conflicts between test and dev environments
    namespace = Rails.env.test? ? :feature_toggle_test : :feature_toggle
    @client ||= Redis::Namespace.new(namespace, redis: redis)
  end

  def self.redis
    @redis ||= Redis.new(url: Rails.application.secrets.redis_url_cache)
  end

  class << self
    private

    # If we do not have any users or regional office restrictions
    # then the feature is enabled *globally* and we accept *all* users
    def enabled_globally?(users:, regional_offices:)
      users.nil? && regional_offices.nil?
    end

    # If users key is set, check if the feature
    # is enabled for the user's css_id
    def enabled_for_user?(users:, user:)
      users.present? && user && users.include?(user.css_id)
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
