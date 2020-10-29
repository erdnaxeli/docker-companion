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

  def get_container_id(name : String) : String?
  end

  def pull_image(image, &block : Companion::Docker::Client::CreateImageResponse ->)
  end

  def start_container(id : String) : Nil
  end
end

DOCKER = FakeDockerClient.new
