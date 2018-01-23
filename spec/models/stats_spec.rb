# frozen_string_literal: true
require "timecop"
require "active_model"
require "pry"

describe Caseflow::Stats do
  before do
    Rails.stub(:cache) { FakeCache.instance }
    Rails.cache.clear
  end

  let(:time) { Timecop.freeze(Time.utc(2017, 1, 0o1, 20, 59, 0)) }
  after(:all) { Timecop.return }

  context "#range" do
    subject { Caseflow::Stats.new(time: time, interval: interval).range }

    context "calculates hourly range" do
      let(:interval) { "hourly" }
      it { is_expected.to eq time.beginning_of_hour..(time + 1.hour).beginning_of_hour }
    end

    context "calculates daily range" do
      let(:interval) { "daily" }
      it { is_expected.to eq time.beginning_of_day..(time + 1.day).beginning_of_day }
    end

    context "calculates weekly range" do
      let(:interval) { "weekly" }
      it { is_expected.to eq time.beginning_of_week..(time + 1.week).beginning_of_week }
    end

    context "calculates yearly range" do
      let(:interval) { "monthly" }
      it { is_expected.to eq time.beginning_of_month..(time + 1.month).beginning_of_month }
    end
  end

  context ".percentile" do
    class Thing
      include ActiveModel::Model
      attr_accessor :spiffyness
    end

    subject { Caseflow::Stats.percentile(:spiffyness, collection, 95) }

    context "with empty collection" do
      let(:collection) { [] }

      it { is_expected.to be_nil }
    end

    context "with nil values" do
      let(:collection) do
        [1, 45, nil, 2, 3, 4, 6, nil].map { |s| Thing.new(spiffyness: s) }
      end

      it { is_expected.to eq(45) }
    end

    context "with small collection" do
      let(:collection) do
        [1, 45, 2, 3, 4, 6].map { |s| Thing.new(spiffyness: s) }
      end

      it { is_expected.to eq(45) }
    end

    context "with large collection" do
      let(:collection) do
        (1..99).map { |s| Thing.new(spiffyness: s * 100) } + [Thing.new(spiffyness: 9501)]
      end

      it { is_expected.to eq(9501) }
    end
  end

  context "#values" do
    class WonderfulThing
    end

    class TestStats < Caseflow::Stats
      CALCULATIONS = {
        wonderful_things_happened: lambda do |_range|
          ObjectSpace.each_object(WonderfulThing).count
        end
      }.freeze
    end

    let(:stats) { TestStats.new(time: TestStats.now, interval: "daily") }
    subject { stats.values }

    context "when cached stat values exist" do
      before do
        Rails.cache.write("TestStats-2017-1-1", wonderful_things_happened: 55)
      end

      it "loads cached value" do
        expect(subject[:wonderful_things_happened]).to eq(55)
      end
    end

    context "when no cached stat values exist" do
      before do
        4.times { WonderfulThing.new }
      end

      it "calculates and caches values" do
        expect(subject[:wonderful_things_happened]).to eq(4)
      end
    end
  end
end
