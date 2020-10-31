require "./spec_helper"

require "path"

describe Companion::Project do
  it "can iterates over images" do
    compose = Companion::Docker::Compose.from_yaml(%(
version: "3.8"
services:
  test:
    image: test:latest
  tada:
    image: tada:42-tiny
        ))

    project = Companion::Project.new(compose)
    images = Array(String).new
    project.each_image do |image|
      images << image
    end

    images.should eq(["test:latest", "tada:42-tiny"])
  end

  it "can fix mounts" do
    compose = Companion::Docker::Compose.from_yaml(%(
      version: "3.8"
      services:
        test:
          image: test:latest
        tada:
          image: tada:42-tiny
          volumes:
            - /something
            - /something/else:/tmp
            - ../data/look/here:/tmp/data
        toto:
          image: todo:abc
          volumes:
            - ./here:/here
            - /here:/not-here
    ))

    project = Companion::Project.new(compose)
    project.fix_mounts(Path["/var/log"])

    project.compose.services[1].volumes[0].source.should be_nil
    project.compose.services[1].volumes[0].target.should eq("/something")
    project.compose.services[1].volumes[1].source.should eq("/something/else")
    project.compose.services[1].volumes[1].target.should eq("/tmp")
    project.compose.services[1].volumes[2].source.should eq("/var/data/look/here")
    project.compose.services[1].volumes[2].target.should eq("/tmp/data")

    project.compose.services[2].volumes[0].source.should eq("/var/log/here")
    project.compose.services[2].volumes[0].target.should eq("/here")
    project.compose.services[2].volumes[1].source.should eq("/here")
    project.compose.services[2].volumes[1].target.should eq("/not-here")
  end
end
