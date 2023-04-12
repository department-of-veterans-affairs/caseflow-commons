require "spec_helper"
require "pry"
describe Caseflow::DocumentTypes do
  it "Checks data type is a hash and will return truthy" do
    expect(described_class::TYPES).is_a?(Hash)
  end
  it "Expects specific key value pair is present in the hash" do
    expect(described_class::TYPES).to include(1797 => "VA Form 26-6808 - Loan Service Report")
  end
  it "Expects Count to not equal to old list count" do
    expect(described_class::TYPES.length).not_to eq(1081)
  end
  it "Expects Count to be equal to new list count" do
    expect(described_class::TYPES.length).to eq(1546)
  end
end