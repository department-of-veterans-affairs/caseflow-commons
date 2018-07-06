require "spec_helper"
require 'fakeweb'

describe Caseflow::PushgatewayService do
  context "mock tests" do
    before { FakeWeb.allow_net_connect = false }
    after { FakeWeb.clean_registry }

    context "service offline" do
      it "unhealthy when service is not running" do
        pushgateway = Caseflow::PushgatewayService.new
        expect(pushgateway.is_healthy?.to eq(false))
      end
    end

    context "service online and unhealthy" do
      before {
        FakeWeb.register_uri(
          :get, "http://127.0.0.1:9091/-/healthy",
          :body => "Error",
          :status => ["503", "Service Unavailable"])}
      after { FakeWeb.clean_registry }
      
      it "unhealthy when service generates non-2xx status" do
        pushgateway = Caseflow::PushgatewayService.new
        expect(pushgateway.is_healthy?.to eq(false))
      end
    end

    context "service online and healthy" do
      before {
        FakeWeb.register_uri(
          :get, "http://127.0.0.1:9091/-/healthy",
          :body => "OK")}
      after { FakeWeb.clean_registry }
      
      it "healthy when service generates 2xx status" do
        pushgateway = Caseflow::PushgatewayService.new
        expect(pushgateway.is_healthy?.to eq(true))
      end
    end
  end
end