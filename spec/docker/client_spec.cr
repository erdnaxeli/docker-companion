require "webmock"

require "./spec_helper"

describe Companion::Docker::Client::Local do
  it "gets known container id" do
    client = Companion::Docker::Client::Local.new

    WebMock.wrap do
      WebMock.stub(:get, "localhost/containers/json?all=true").to_return(
        body: CONTAINERS_JSON
      )

      id = client.get_container_id("sleepy_dog")
      id.should eq("3176a2479c92")
    end
  end
end
