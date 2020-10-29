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
