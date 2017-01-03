require 'active_model'
require 'timecop'

describe Caseflow::Stats do

  let(:time) { Timecop.freeze(Time.new(2017, 1, 01, 20, 59, 0)) }

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

  context "#percentile" do
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
end
