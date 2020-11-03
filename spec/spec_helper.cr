require "spec"
require "../src/docker-companion"

DOCKER_COMPOSE = %(
version: "3.8"
services:
    test:
        image: test
)

class FakeDockerClient
  include Companion::Docker::Client

  alias CreateContainerCall = {options: CreateContainerOptions, name: String}

  property create_container_calls = Array(CreateContainerCall).new
  getter networks = Array(Network).new

  def create_container(options, name) : CreateContainerResponse
    @create_container_calls << {options: options, name: name}

    CreateContainerResponse.from_json("{}")
  end

  def create_network(options) : CreateNetworkResponse
    CreateNetworkResponse.from_json(%({"Id": "#{options.name}_id"}))
  end

  def get_container_id(name) : String?
  end

  def images : Array(Image)
    Array(Image).new
  end

  def pull_image(image, tag = "latest", &block : CreateImageResponse ->)
  end

  def start_container(id) : Nil
  end

  def reset
    @create_container_calls = Array(CreateContainerCall).new
  end
end

DOCKER = FakeDockerClient.new
