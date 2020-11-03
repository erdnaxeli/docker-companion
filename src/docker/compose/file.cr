require "yaml"

class Companion::Docker::Compose
  class File
    include YAML::Serializable

    property version : String
    property services : Hash(String, Service)
    property networks : Hash(String, Network)?
  end
end

class Companion::Docker::Compose::File::Service
  include YAML::Serializable

  property build : String?
  property container_name : String?
  property image : String?
  property restart : String?
  property ports : Array(String)?
  property volumes : Array(String)?
  property networks : Array(String)?
  property labels : Hash(String, String)?
end

class Companion::Docker::Compose::File::Network
  include YAML::Serializable

  property external : Bool?
end
