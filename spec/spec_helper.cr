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

  alias CreateContainerCall = {options: Companion::Docker::CreateContainerOptions, name: String}

  property create_container_calls = Array(CreateContainerCall).new

  def create_container(options, name) : CreateContainerResponse
    @create_container_calls << {options: options, name: name}

    CreateContainerResponse.from_json("{}")
  end

  def get_container_id(name) : String?
  end

  def images : Array(Companion::Docker::Image)
    Array(Companion::Docker::Image).new
  end

  def pull_image(image, &block : Companion::Docker::Client::CreateImageResponse ->)
  end

  def start_container(id) : Nil
  end

  def reset
    @create_container_calls = Array(CreateContainerCall).new
  end
end

DOCKER = FakeDockerClient.new
