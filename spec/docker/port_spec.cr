require "./spec_helper"

describe Companion::Docker::Port do
  it "deserializes port type" do
    port = Companion::Docker::Port.from_json(
      %({"PrivatePort": 42, "Type": "udp"})
    )

    port.type.should eq(Companion::Docker::Port::Type::Udp)
  end

  it "serializes port type" do
    port = Companion::Docker::Port.new(
      private_port: 42i16,
      type: Companion::Docker::Port::Type::Udp
    )
    port.to_json.should eq(%({"PrivatePort":42,"Type":"udp"}))
  end
end
