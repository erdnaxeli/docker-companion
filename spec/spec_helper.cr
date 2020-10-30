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

  def create_container(options, name) : CreateContainerResponse
    CreateContainerResponse.from_json("{}")
  end

  def get_container_id(name) : String?
  end

  def pull_image(image, &block : Companion::Docker::Client::CreateImageResponse ->)
  end

  def start_container(id) : Nil
  end
end

DOCKER = FakeDockerClient.new
