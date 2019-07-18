require "spec_helper"
require "pry"

describe Caseflow::PushgatewayService do
  context "mock tests" do
    context "service offline" do
      before do
        WebMock.disable_net_connect!(allow_localhost: true)
      end

      it "unhealthy when service is not running" do
        pushgateway = Caseflow::PushgatewayService.new
        expect(pushgateway.healthy?).to eq(false)
      end
    end

    context "service online and unhealthy" do
      before do
        stub_request(:get, "http://127.0.0.1:9091/-/healthy").to_return(body: "Error", status: ["503", "Service Unavailable"])
      end

      it "unhealthy when service generates non-2xx status" do
        pushgateway = Caseflow::PushgatewayService.new
        expect(pushgateway.healthy?).to eq(false)
      end
    end

    context "service online and healthy" do
      before do
        stub_request(:get, "http://127.0.0.1:9091/-/healthy").to_return(body: "OK")
      end

      it "healthy when service generates 2xx status" do
        pushgateway = Caseflow::PushgatewayService.new
        expect(pushgateway.healthy?).to eq(true)
      end
    end
  end
end
