require "json"
require "socket"

require "./container"
require "./exceptions"
require "./image"
require "./network"
require "../../macro"

module Companion::Docker::Client
  struct CreateContainerResponse
    include JSON::Serializable

    json_property Id, id : String?
    json_property warnings : Array(String)?
    property message : String?
  end

  struct CreateImageResponse
    include JSON::Serializable

    property status : String?
    property progress : String?
    property id : String?
  end

  abstract def create_container(options : CreateContainerOptions, name : String) : CreateContainerResponse
  # Creates a network.
  abstract def create_network(options : CreateNetworkOptions) : CreateNetworkResponse

  # Get a container's id.
  #
  # Returns nil if the container is not found.
  abstract def get_container_id(name : String) : String?

  # Get a container's logs
  abstract def get_logs(id : String, stdout : Bool, stderr : Bool, lines : Int32) : String

  # Get images.
  abstract def images : Array(Image)

  # Pull an image from Docker Hub.
  #
  # Yield `CreateImageResponse` objects.
  abstract def pull_image(name, &block : CreateImageResponse ->)

  # Start a container.
  abstract def start_container(id : String) : Nil
end

class Companion::Docker::Client::Local
  include Client

  @client : HTTP::Client

  struct Config
    property socket = "/var/run/docker.sock"
  end

  def initialize(@config = Config.new)
    @client = HTTP::Client.new(UNIXSocket.new(@config.socket))
  end

  # Creates a new container and return its id.
  def create_container(options : CreateContainerOptions, name : String? = nil) : CreateContainerResponse
    route = name ? "/containers/create?name=#{name}" : "/containers/create"
    raw_response = @client.post("http://localhost#{route}", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: options.to_json)
    response = CreateContainerResponse.from_json(raw_response.body)

    if !raw_response.success?
      case raw_response.status_code
      when 409
        raise ConflictException.new(response.message)
      else
        raise "Invalid status code #{raw_response.status_code}: #{raw_response.body}"
      end
    end

    response
  end

  def create_network(options : CreateNetworkOptions) : CreateNetworkResponse
    raw_response = @client.post("http://localhost/networks/create", headers: HTTP::Headers{"Content-Type" => "application/json"}, body: options.to_json)
    CreateNetworkResponse.from_json(raw_response.body)
  end

  # Create an image and returns its id
  def create_image(from_image : String, tag : String)
    params = HTTP::Params.encode({fromImage: from_image, tag: tag})
    @client.post("http://localhost/images/create?#{params}") do |response|
      response.body_io.each_line do |line|
        yield CreateImageResponse.from_json(line)
      end
    end
  end

  # Connect a container to a network
  def connect_network(options : ConnectNetworkOptions) : Nil
    response = @client.post(
      "http://localhost/networks/#{options.endpoint_config.network_id}/connect",
      headers: HTTP::Headers{"Content-Type" => "application/json"},
      body: options.to_json
    )

    if !response.success?
      raise "Invalid status code #{response.status_code}: #{response.body}"
    end
  end

  # Lists containers.
  #
  # By default list only running ones. Set *all* to `true` to get all containers.
  def containers(all = false) : Array(Container)
    params = HTTP::Params.encode({all: all.to_s})
    route = "/containers/json?#{params}"
    response = @client.get route
    Array(Container).from_json(response.body)
  end

  def get_container_id(name : String) : String?
    containers(true).each do |container|
      container.names.each do |container_name|
        if container_name == "/#{name}"
          return container.id
        end
      end
    end
  end

  def get_logs(id : String, stdout : Bool, stderr : Bool, lines : Int32) : String
    response = @client.get("http://localhost/containers/#{id}/logs?stdout=#{stdout}&stderr={stderr}&tail=#{lines}")
    response.body.lines.map { |l| String.new(l.to_slice[8...]) }.join("\n")
  end

  def images : Array(Image)
    response = @client.get("http://localhost/images/json")
    Array(Image).from_json(response.body)
  end

  def networks : Array(Network)
    response = @client.get("http://localhost/networks")
    Array(Network).from_json(response.body)
  end

  # Pulls an image from dockerhub
  def pull_image(name, tag = "latest", &block : CreateImageResponse ->)
    create_image(name, tag) { |response| yield response }
  end

  # Removes a containers.
  #
  # If the container is running, it will be killed.
  def remove_container(id : String) : Nil
    @client.delete("http://localhost/containers/#{id}?force=true")
  end

  # Starts a container.
  def start_container(id : String) : Nil
    @client.post("http://localhost/containers/#{id}/start")
  end
end
