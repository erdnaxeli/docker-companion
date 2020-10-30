require "./spec_helper"

describe Companion::Manager do
  it "can add project" do
    manager = Companion::Manager.new(DOCKER)
    manager.add_project("test", DOCKER_COMPOSE)
    manager.add_project("test2", DOCKER_COMPOSE)
  end

  it "prevents duplicates projects" do
    manager = Companion::Manager.new(DOCKER)
    manager.add_project("test", DOCKER_COMPOSE)

    expect_raises(Exception, "The projects test already exists") do
      manager.add_project("test", DOCKER_COMPOSE)
    end
  end

  it "can create containers for a project" do
    manager = Companion::Manager.new(DOCKER)
    manager.add_project(
      "test",
      %(
        version: 3.8
        services:
          test:
            image: bash:latest
          tada:
            image: python:3.8
      ),
    )
    manager.create("test")

    DOCKER.create_container_calls.size.should eq(2)
    DOCKER.create_container_calls[0][:options].image.should eq("bash:latest")
    DOCKER.create_container_calls[0][:name].should eq("test_test")
    DOCKER.create_container_calls[1][:options].image.should eq("python:3.8")
    DOCKER.create_container_calls[1][:name].should eq("test_tada")
  end

  it "raises when creating containers for an unknown project" do
    manager = Companion::Manager.new(DOCKER)
    manager.add_project("test", DOCKER_COMPOSE)

    expect_raises(Exception, "Unknown project tada") do
      manager.create("tada")
    end
  end

  it "raises when pulling images for an unknown project" do
    manager = Companion::Manager.new(DOCKER)
    manager.add_project("test", DOCKER_COMPOSE)

    expect_raises(Exception, "Unknown project tada") do
      manager.pull_images("tada")
    end
  end

  it "raises when starting an unknown project" do
    manager = Companion::Manager.new(DOCKER)
    manager.add_project("test", DOCKER_COMPOSE)

    expect_raises(Exception, "Unknown project tada") do
      manager.start("tada")
    end
  end
end
