require "./macro"

class Companion::Docker::Port
  include JSON::Serializable

  enum Type
    Tcp
    Udp
    Sctp

    def to_json(json)
      json.string(self.to_s.downcase)
    end
  end

  def initialize(@private_port, @type, @ip = nil, @public_port = nil)
  end

  json_property "IP", ip : String?
  json_property private_port : Int16
  json_property public_port : Int16?
  json_property type : Type
end
