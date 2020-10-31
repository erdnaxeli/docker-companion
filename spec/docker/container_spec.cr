require "json"

require "./spec_helper"

describe Companion::Docker::Container do
  it "deserializes docker doc example" do
    Array(Companion::Docker::Container).from_json(CONTAINERS_JSON)
  end
end

describe Companion::Docker::CreateContainerOptions do
  it "serializes to json" do
    Companion::Docker::CreateContainerOptions.new.to_json
  end
end

describe Companion::Docker::CreateContainerOptions::ExposedPorts do
  it "serializes to json" do
    JSON.build do |json|
      Companion::Docker::CreateContainerOptions::ExposedPorts.new.to_json(json)
    end
  end

  it "can add ports" do
    e = Companion::Docker::CreateContainerOptions::ExposedPorts.new
    e.add_port(22)
    e.add_port(443, Companion::Docker::Port::Type::Udp)

    str = JSON.build do |json|
      e.to_json(json)
    end

    str.should eq(%({"22/tcp":{},"443/udp":{}}))
  end
end

describe Companion::Docker::CreateContainerOptions::Env do
  it "serializes to json" do
    JSON.build do |json|
      Companion::Docker::CreateContainerOptions::Env.new.to_json(json)
    end
  end

  it "can add var" do
    env = Companion::Docker::CreateContainerOptions::Env.new
    env << {"SOME_VAR", "some value"}
    env << {"lalala", "I like piñatas"}

    str = JSON.build do |json|
      env.to_json(json)
    end

    str.should eq(%{["SOME_VAR=some value","LALALA=I like piñatas"]})
  end
end

describe Companion::Docker::CreateContainerOptions::Volumes do
  it "serializes to json" do
    JSON.build do |json|
      Companion::Docker::CreateContainerOptions::Volumes.new.to_json(json)
    end
  end

  it "can add var" do
    volumes = Companion::Docker::CreateContainerOptions::Volumes.new
    volumes << "/var/run"
    volumes << "/home"

    str = JSON.build do |json|
      volumes.to_json(json)
    end

    str.should eq(%{{"/var/run":{},"/home":{}}})
  end
end

describe Companion::Docker::CreateContainerOptions::HostConfig do
  it "serializes to json" do
    Companion::Docker::CreateContainerOptions::HostConfig.new.to_json
  end
end

describe Companion::Docker::CreateContainerOptions::HostConfig::Mount do
  it "serializes to json" do
    Companion::Docker::CreateContainerOptions::HostConfig::Mount.new.to_json
  end
end

describe Companion::Docker::CreateContainerOptions::HostConfig::Mount::Type do
  it "serializes to json" do
    str = JSON.build do |json|
      Companion::Docker::CreateContainerOptions::HostConfig::Mount::Type::Bind.to_json(json)
    end

    str.should eq(%("bind"))
  end
end

describe Companion::Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name do
  it "serializes No to json" do
    str = JSON.build do |json|
      Companion::Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::No.to_json(json)
    end

    str.should eq (%("no"))
  end

  it "serializes Always to json" do
    str = JSON.build do |json|
      Companion::Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::Always.to_json(json)
    end

    str.should eq (%("always"))
  end

  it "serializes OnFailure to json" do
    str = JSON.build do |json|
      Companion::Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::OnFailure.to_json(json)
    end

    str.should eq (%("on-failure"))
  end

  it "serializes UnlessStopped to json" do
    str = JSON.build do |json|
      Companion::Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::UnlessStopped.to_json(json)
    end

    str.should eq (%("unless-stopped"))
  end
end
