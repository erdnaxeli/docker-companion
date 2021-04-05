require "webmock"

require "./spec_helper"

describe Companion::Docker::Client::Local do
  it "gets known container id" do
    client = Companion::Docker::Client::Local.new

    WebMock.wrap do
      WebMock.stub(:get, "/containers/json?all=true").to_return(
        body: CONTAINERS_JSON
      )

      id = client.get_container_id("sleepy_dog")
      id.should eq("3176a2479c92")
    end
  end

  it "gets images" do
    client = Companion::Docker::Client::Local.new

    WebMock.wrap do
      WebMock.stub(:get, "/images/json").to_return(
        body: IMAGES_JSON
      )

      images = client.images
      images.size.should eq(2)
      images[0].id.should eq("sha256:e216a057b1cb1efc11f8a268f37ef62083e70b1b38323ba252e25ac88904a7e8")
      images[0].repo_tags.should be_nil
      images[1].id.should eq("sha256:3e314f95dcace0f5e4fd37b10862fe8398e3c60ed36600bc0ca5fda78b087175")
      images[1].repo_tags.should eq(["ubuntu:12.10", "ubuntu:quantal"])
    end
  end
end
