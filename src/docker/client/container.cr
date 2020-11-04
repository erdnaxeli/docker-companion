require "json"

require "./port"

class Companion::Docker::Client::Container
  include JSON::Serializable

  json_property id : String
  json_property names : Array(String)
  json_property image : String
  json_property "ImageID", image_id : String?
  json_property command : String
  json_property created : Int64
  json_property ports : Array(Port)
end

class Companion::Docker::Client::CreateContainerOptions
  include JSON::Serializable

  class ExposedPorts
    @ports = Array(Tuple(Int16, Port::Type)).new

    def add_port(port : Int16, type = Port::Type::Tcp) : Nil
      @ports << {port, type}
    end

    def to_json(json)
      json.object do
        @ports.each do |t|
          json.field("#{t[0]}/#{t[1].to_s.downcase}") { json.object { } }
        end
      end
    end
  end

  class Env < Hash(String, String)
    def to_json(json)
      json.array do
        self.each do |key, value|
          json.string("#{key.upcase}=#{value}")
        end
      end
    end
  end

  class Volumes
    @volumes = Array(String).new

    def <<(volume)
      @volumes << volume
    end

    def to_json(json)
      json.object do
        @volumes.each do |volume|
          json.field(volume) { json.object { } }
        end
      end
    end
  end

  class HostConfig
    include JSON::Serializable

    class Mount
      include JSON::Serializable

      enum Type
        Bind
        Volume
        Tmpfs
        Npipe

        def to_json(json)
          json.string(self.to_s.downcase)
        end
      end

      def initialize
      end

      json_property target = ""
      json_property source = ""
      json_property type = Type::Bind
    end

    class PortBinding
      include JSON::Serializable

      def initialize
      end

      json_property host_ip = ""
      json_property host_port = ""
    end

    class RestartPolicy
      include JSON::Serializable

      enum Name
        No
        Always
        OnFailure
        UnlessStopped

        def to_json(json)
          case self
          when No
            json.string("no")
          when Always
            json.string("always")
          when OnFailure
            json.string("on-failure")
          when UnlessStopped
            json.string("unless-stopped")
          end
        end
      end

      def initialize
      end

      property name = Name::No
      json_property maximum_retry_count = 0
    end

    def initialize
    end

    json_property mounts = Array(Mount).new
    json_property port_bindings = Hash(String, Array(PortBinding)).new
    json_property restart_policy = RestartPolicy.new
  end

  class NetworkingConfig
    include JSON::Serializable

    def initialize
    end

    json_property endpoints_config = Hash(String, EndpointConfig).new
  end

  class EndpointConfig
    include JSON::Serializable

    def initialize
    end

    json_property aliases = Array(String).new
    json_property "NetworkID", network_id = ""
  end

  def initialize
  end

  json_property hostname = ""
  json_property user = ""
  json_property exposed_ports = ExposedPorts.new
  json_property env = Env.new
  json_property cmd = Array(String).new
  json_property image = ""
  json_property volumes = Volumes.new
  json_property labels : Hash(String, String)?
  json_property host_config = HostConfig.new
  json_property networking_config = NetworkingConfig.new
end

class Companion::Docker::Client::ConnectNetworkOptions
  include JSON::Serializable

  def initialize
  end

  json_property container = ""
  json_property endpoint_config = CreateContainerOptions::EndpointConfig.new
end
