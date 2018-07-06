require "spec_helper"
require "pry"

describe Caseflow::PushgatewayService do
  context "live tests" do
    it "fails when service is not running" do
      expect(Caseflow::PushgatewayService.is_healthy?.to eq(false)
    end
  end
end