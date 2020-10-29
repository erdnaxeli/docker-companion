require "./spec_helper"

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
end
