require "spec_helper"
require "pry"

describe Caseflow::PushgatewayService do
  context "live tests" do
    it "fails when service is not running" do
      pushgateway = Caseflow::PushgatewayService.new
      expect(pushgateway.is_healthy?.to eq(false))
    end
  end
end