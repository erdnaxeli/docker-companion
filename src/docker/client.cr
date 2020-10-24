require "json"

require "./container"
require "./macro"
require "../core_ext/http/client"

class Companion::Docker::Client
  struct Config
    property socket = "/var/run/docker.sock"
  end

  struct CreateContainerResponse
    include JSON::Serializable

    json_property ID, id : String?
    json_property warnings : Array(String)?
    property message : String?
  end

  @client = HTTP::Client.new("localhost")

  def initialize(@config : Config)
    connect
  end

  # Create a new container and return its id.
  def create_container(container : CreateContainerOptions) : CreateContainerResponse
    response = @client.post "/containers/create", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: container.to_json
    CreateContainerResponse.from_json(response.body)
  end

  # List containers.
  #
  # By default list only running ones. Set *all* to `true` to get all containers.
  def containers(all = false) : Array(Container)
    params = HTTP::Params.encode({all: all.to_s})
    route = "/containers/json?#{params}"
    response = @client.get route
    Array(Container).from_json(response.body)
  end

  private def connect
    @client = HTTP::Client.unix(@config.socket)
  end
end
