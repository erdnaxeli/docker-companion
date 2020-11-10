require "json"

require "../../macro"

class Companion::Docker::Client::Network
  include JSON::Serializable

  json_property id : String
  json_property name : String
end

class Companion::Docker::Client::CreateNetworkOptions
  include JSON::Serializable

  def initialize
  end

  json_property name = ""
end

class Companion::Docker::Client::CreateNetworkResponse
  include JSON::Serializable

  json_property id : String
end
