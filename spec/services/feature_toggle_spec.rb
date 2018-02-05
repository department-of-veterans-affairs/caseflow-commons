require "spec_helper"

describe FeatureToggle do
  let(:user1) { OpenStruct.new(regional_office: "RO03", css_id: "5") }
  let(:user2) { OpenStruct.new(regional_office: "RO07", css_id: "7") }
  let(:user3) { OpenStruct.new(regional_office: "RO07", css_id: "CSSID") }
  features_config = '[
   {
      feature: "all_feature",
      enable_all: true
    },
    {
      feature: "users_feature",
      users: ["Good", "Bad", "Ugly"]
    },
    {
      feature: "offices_feature",
      regional_offices: ["O.K.Corral", "Alamo"]
    },
    {
      feature: "users_and_offices",
      users: ["Good", "Bad", "Ugly"],
      regional_offices: ["O.K.Corral", "Alamo", "Tombstone"]
    }]'

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
      subject { FeatureToggle.enable!(:test, regional_offices: %w[RO01 RO02 RO03]) }

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

      it "feature is enabled for individual user" do
        subject
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq false
      end

      it "can be enabled for more users" do
        subject
        FeatureToggle.enable!(:test, users: [user2.css_id])
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq true
      end

      it "is not case sensitive" do
        subject
        expect(FeatureToggle.enabled?(:test, user: user3)).to eq false
        FeatureToggle.enable!(:test, users: [user3.css_id.downcase])
        expect(FeatureToggle.enabled?(:test, user: user3)).to eq true
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
        FeatureToggle.enable!(:test, regional_offices: %w[RO07 RO03])
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
        FeatureToggle.enable!(:test, regional_offices: %w[RO03 RO02 RO09])
      end
      subject { FeatureToggle.disable!(:test, regional_offices: %w[RO03 RO02 RO09]) }

      it "feature becomes disabled for everyone" do
        subject
        expect(FeatureToggle.enabled?(:test)).to eq false
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq false
      end
    end

    context "when regional_offices becomes an empty array but users are still present" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w[RO03 RO02 RO09], users: [user1.css_id])
      end
      subject { FeatureToggle.disable!(:test, regional_offices: %w[RO03 RO02 RO09]) }

      it "feature is still enabled for a set of users" do
        subject
        expect(FeatureToggle.enabled?(:test)).to eq false
        expect(FeatureToggle.enabled?(:test, user: user1)).to eq true
        expect(FeatureToggle.enabled?(:test, user: user2)).to eq false
      end
    end

    context "when sending an empty array" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w[RO03 RO02 RO09])
      end
      subject { FeatureToggle.disable!(:test, regional_offices: []) }

      it "no regional offices are disabled" do
        subject
        expect(FeatureToggle.details_for(:test)[:regional_offices]).to eq %w[RO03 RO02 RO09]
      end
    end

    context "when sending incorrect regional offices" do
      before do
        FeatureToggle.enable!(:test, regional_offices: %w[RO03 RO02 RO09])
      end
      subject { FeatureToggle.disable!(:test, regional_offices: ["RO01"]) }

      it "no regional offices are disabled" do
        subject
        expect(FeatureToggle.details_for(:test)[:regional_offices]).to eq %w[RO03 RO02 RO09]
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

      it { is_expected.to eq [:search, :test] }
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
      it { is_expected.to be_empty }
    end

    context "when not enabled" do
      it { is_expected.to be nil }
    end

    context "when enabled for a list of regional offices" do
      before do
        FeatureToggle.enable!(:banana, regional_offices: %w[RO03 RO02 RO09])
      end
      it { is_expected.to eq(regional_offices: %w[RO03 RO02 RO09]) }
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
        FeatureToggle.enable!(:search, regional_offices: %w[RO01 RO02 RO03])
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

  context ".sync!" do
    before :each do
      FeatureToggle.redis.flushall
    end

    context "when there are no existing features enabled" do
      before do
        FeatureToggle.sync!(features_config)
      end

      it "sets new features" do
        expect(FeatureToggle.details_for(:all_feature)).to be_empty
        expect(FeatureToggle.details_for(:users_feature)[:users]).to eql %w[Good Bad Ugly]
        expect(FeatureToggle.details_for(:offices_feature)[:regional_offices]).to eql ["O.K.Corral", "Alamo"]
      end
    end

    context "when existing features are enabled for all" do
      before do
        FeatureToggle.enable!(:all_feature)
        FeatureToggle.enable!(:users_feature)
        FeatureToggle.enable!(:offices_feature)
        FeatureToggle.enable!(:users_and_offices)
        FeatureToggle.sync!(features_config)
      end

      it "all_feature stays the same" do
        expect(FeatureToggle.details_for(:all_feature)).to be_empty
        expect(FeatureToggle.details_for(:users_feature)[:users]).to eql %w[Good Bad Ugly]
        expect(FeatureToggle.details_for(:offices_feature)[:regional_offices]).to eql ["O.K.Corral", "Alamo"]
        expect(FeatureToggle.details_for(:users_and_offices)[:users]).to eql %w[Good Bad Ugly]
        expect(FeatureToggle.details_for(:users_and_offices)[:regional_offices]).to eql ["O.K.Corral", "Alamo", "Tombstone"]
      end
    end

    context "where existing features and new hash have common members" do
      before do
        FeatureToggle.enable!(:all_feature, users: ["Il cattivo"])
        FeatureToggle.enable!(:some_other_feature)
        FeatureToggle.enable!(:users_feature, users: ["Good", "Il Buono"])
        FeatureToggle.enable!(:offices_feature, regional_offices: ["O.K.Corral", "Alamo", "Rio Bravo"])
        FeatureToggle.enable!(:users_and_offices, users: ["Good", "Bad", "Il Brutto"])
        FeatureToggle.enable!(:users_and_offices, regional_offices: ["O.K.Corral", "Alamo", "Rio Bravo"])
        FeatureToggle.sync!(features_config)
      end

      it "enables only new members" do
        expect(FeatureToggle.features.sort).to eq [:all_feature, :offices_feature, :users_and_offices, :users_feature]
        expect(FeatureToggle.details_for(:all_feature)).to be_empty
        expect(FeatureToggle.details_for(:some_other_feature)).to eql nil
        expect(FeatureToggle.details_for(:users_feature)[:users]).to eql %w[Good Bad Ugly]
        expect(FeatureToggle.details_for(:offices_feature)[:regional_offices]).to eql ["O.K.Corral", "Alamo"]
        expect(FeatureToggle.details_for(:users_feature)[:users]).to eql %w[Good Bad Ugly]
        expect(FeatureToggle.details_for(:users_and_offices)[:users]).to eql %w[Good Bad Ugly]
        expect(FeatureToggle.details_for(:users_and_offices)[:regional_offices]).to eql ["O.K.Corral", "Alamo", "Tombstone"]
      end
    end

    context "validate config object" do
      it "fails when env hash has a key that doesn't belong" do
        features_config = '[
           {
              feature: "all_feature",
              fake_key: true,
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Unknown key found in config object")
      end

      it "fails when env hash has no key 'feature'" do
        features_config = '[
           {
              enable_all: true
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Missing feature key in config object")
      end

      it "fails when ambiguous input" do
        features_config = '[
           {
              feature: "reader",
              enable_all: true,
              users: ["Good"]
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Ambiguous input")
      end

      it "fails when there are no values specified" do
        features_config = '[
           {
              feature: "reader",
              enable_all:
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Missing values in config object")
      end

      it "fails when feature is not a string" do
        features_config = '[
           {
              feature: true,
              enable_all: true
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Feature value should be a string")
      end

      it "fails when feature is empty string" do
        features_config = '[
           {
              feature: "",
              enable_all: true
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Empty string in feature")
      end

      it "fails when enable_all has other than true value" do
        features_config = '[
           {
              feature: "reader",
              enable_all: false
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("enable_all value has to be true")
      end

      it "fails when users value is not an array" do
        features_config = '[
           {
              feature: "reader",
              users: true
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("users value should be an array")
      end

      it "fails when regional_offices value is not an array" do
        features_config = '[
           {
              feature: "reader",
              regional_offices: true
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("regional_offices value should be an array")
      end

      it "fails when users value is empty array" do
        features_config = '[
           {
              feature: "reader",
              users: []
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Empty array for users")
      end

      it "fails when regional_offices value is empty array" do
        features_config = '[
           {
              feature: "reader",
              regional_offices: []
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Empty array for regional_offices")
      end

      it "fails when values for users are not strings" do
        features_config = '[
           {
              feature: "reader",
              users: [true]
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("users values have to be strings")
      end

      it "fails when values for regional offices are specified, but empty" do
        features_config = '[
           {
              feature: "reader",
              regional_offices: [true]
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("regional_offices values have to be strings")
      end

      it "fails when values for users are specified, but empty" do
        features_config = '[
           {
              feature: "reader",
              users: [""]
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Empty string in users")
      end

      it "fails when values for regional offices are specified, but empty" do
        features_config = '[
           {
              feature: "reader",
              regional_offices: [""]
            }]'
        expect { FeatureToggle.sync!(features_config) }.to raise_error("Empty string in regional_offices")
      end
    end
  end
end
