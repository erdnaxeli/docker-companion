require "./macro"

class Companion::Docker::Port
  include JSON::Serializable

  enum PortType
    Tcp
    Udp
    Sctp

    def to_json(json)
      json.string(self.to_s.downcase)
    end
  end

  def initialize(@private_port, @type, @ip = nil, @public_port = nil)
  end

  json_property ip, IP, String?
  json_property private_port, Int16
  json_property public_port, Int16?
  json_property type, PortType
end
