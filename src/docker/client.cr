require "./container"
require "../core_ext/http/client"

class Companion::Docker::Client
  struct Config
    property socket = "/var/run/docker.sock"
  end

  @client = HTTP::Client.new("localhost")

  def initialize(@config : Config)
    connect
  end

  def create_container(container : CreateContainerOptions)
    @client.post "/containers/create", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: container.to_json
  end

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
