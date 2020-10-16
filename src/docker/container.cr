require "json"

require "./port"

class Companion::Docker::Container
  include JSON::Serializable

  json_property id, String
  json_property names, Array(String)
  json_property image, String
  json_property image_id, String?
  json_property command, String
  json_property created, Int64
  json_property ports, Array(Port)
end
