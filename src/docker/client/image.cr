require "json"

require "../../macro"

class Companion::Docker::Client::Image
  include JSON::Serializable

  json_property id : String
  json_property repo_tags : Array(String)?
end
