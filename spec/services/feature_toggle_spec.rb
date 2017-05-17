# frozen_string_literal: true

require "spec_helper"
require "redis"
require "redis-namespace"

describe FeatureToggle do
  let(:user1) { OpenStruct.new(regional_office: "RO03", css_id: "5") }
  let(:user2) { OpenStruct.new(regional_office: "RO07", css_id: "7") }

  before :each do
    Rails.stub(:application) { FakeApplication.instance }
    FeatureToggle.redis.flushall
  end

  context ".enable!" do
    context "for everyone" do
      subject { FeatureToggle.enable!(:search) }

      it "feature is enabled for everyone" do
        subject
        expect(FeatureToggle.enabled?(:search, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:search, user: user2)).to eq true
      end
    end

    context "for a set of regional_offices" do
      subject { FeatureToggle.enable!(:test, regional_offices: %w(RO01 RO02 RO03)) }

      it "feature is enabled for users who belong to the regional offices" do
        subject
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq false
      end

      it "enable for more users" do
        subject
        FeatureToggle.enable!(:test, regional_offices: ["RO07"])
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq true
      end
    end

    context "for a set of users" do
      subject { FeatureToggle.enable!(:test, users: [user1.css_id]) }

      it "feature is enabled for inidivual user" do
        subject
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq false
      end

      it "enable for more users" do
        subject
        FeatureToggle.enable!(:test, users: [user2.css_id])
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq true
      end
    end

    context "for an RO and individual users" do
      let(:user3) { OpenStruct.new(regional_office: "RO08", css_id: "9") }

      subject do
        FeatureToggle.enable!(:test, users: [user1.css_id])
        FeatureToggle.enable!(:test, regional_offices: [user2.regional_office])
      end

      it "feature is enabled for RO users and individual non-RO user" do
        subject
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user3)).to eq false
      end
    end
  end

  context ".disable!" do
    context "globally" do
      before do
        FeatureToggle.enable!(:search)
      end
      subject { FeatureToggle.disable!(:search) }

      it "feature is disabled for everyone" do
        subject
        expect(FeatureToggle.enabled?(:search, user: user1)).to eq false
        expect(FeatureToggle.enabled?(:search, user: user2)).to eq false
      end
    end

    context "for a set of regional offices" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w(RO07 RO03))
      end
      subject { FeatureToggle.disable!(:test, regional_offices: ["RO03"]) }

      it "users who belong to the regional offices can no longer access the feature" do
        subject
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq false
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq true
      end
    end

    context "when regional_offices becomes an empty array" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w(RO03 RO02 RO09))
      end
      subject { FeatureToggle.disable!(:test, regional_offices: %w(RO03 RO02 RO09)) }

      it "feature becomes disabled for everyone" do
        subject
        expect(FeatureToggle.enabled?(:test)).to eq false
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq false
      end
    end

    context "when regional_offices becomes an empty array but users are still present" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w(RO03 RO02 RO09), users: [user1.css_id])
      end
      subject { FeatureToggle.disable!(:test, regional_offices: %w(RO03 RO02 RO09)) }

      it "feature is still enabled for a set of users" do
        subject
        expect(FeatureToggle.enabled?(:test)).to eq false
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq false
      end
    end

    context "when sending an empty array" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w(RO03 RO02 RO09))
      end
      subject { FeatureToggle.disable!(:test, regional_offices: []) }

      it "no regional offices are disabled" do
        subject
        expect(FeatureToggle.details_for(:test)[:regional_offices]).to eq %w(RO03 RO02 RO09)
      end
    end

    context "when sending incorrect regional offices" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w(RO03 RO02 RO09))
      end
      subject { FeatureToggle.disable!(:test, regional_offices: ["RO01"]) }

      it "no regional offices are disabled" do
        subject
        expect(FeatureToggle.details_for(:test)[:regional_offices]).to eq %w(RO03 RO02 RO09)
      end
    end

    context "when disabling individual user access" do
      before do
        FeatureToggle.enable!(:test, users: [user1.css_id])
        FeatureToggle.enable!(:test, regional_offices: [user2.regional_office])
      end
      subject { FeatureToggle.disable!(:test, users: [user1.css_id]) }

      it "maintains access for regional offices" do
        subject
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq true
      end
    end
  end

  context ".features" do
    context "when features exist" do
      before do
        FeatureToggle.enable!(:test)
        FeatureToggle.enable!(:test)
        FeatureToggle.enable!(:search)
      end
      subject { FeatureToggle.features.sort }

      it { is_expected.to eq %i(search test) }
    end

    context "when features do not exist" do
      subject { FeatureToggle.features }

      it { is_expected.to eq [] }
    end
  end

  context ".details_for" do
    subject { FeatureToggle.details_for(:banana) }

    context "when enabled globally" do
      before do
        FeatureToggle.enable!(:banana)
      end
      it { is_expected.to be {} }
    end

    context "when not enabled" do
      it { is_expected.to be nil }
    end

    context "when enabled for a list of regional offices" do
      before do
        FeatureToggle.enable!(:banana, regional_offices: %w(RO03 RO02 RO09))
      end
      it { is_expected.to eq(regional_offices: %w(RO03 RO02 RO09)) }
    end
  end

  context ".enabled?" do
    context "when enabled for everyone" do
      before do
        FeatureToggle.enable!(:search)
      end
      subject { FeatureToggle.enabled?(:search, user: user1) }

      it { is_expected.to eq true }
    end

    context "when a feature does not exist in redis" do
      subject { FeatureToggle.enabled?(:foo, user: user1) }

      it { is_expected.to eq false }
    end

    context "when enabled for a set of regional_offices" do
      subject { FeatureToggle.enabled?(:search, user: user) }

      before do
        FeatureToggle.enable!(:search, regional_offices: %w(RO01 RO02 RO03))
      end

      context "if a user is associated with a regional office" do
        let(:user) { OpenStruct.new(regional_office: "RO02") }
        it { is_expected.to eq true }
      end

      context "if a user is not associated with a regional office" do
        let(:user) { OpenStruct.new(regional_office: "RO09") }
        it { is_expected.to eq false }
      end

      context "when user is not passed" do
        let(:user) { nil }
        it { is_expected.to eq false }
      end
    end
  end
end
