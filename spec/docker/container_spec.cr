require "json"

require "./spec_helper"

describe Companion::Docker::Container do
  it "deserializes docker doc example" do
    Array(Companion::Docker::Container).from_json(%(
      [
  {
    "Id": "8dfafdbc3a40",
    "Names": [
      "/boring_feynman"
    ],
    "Image": "ubuntu:latest",
    "ImageID": "d74508fb6632491cea586a1fd7d748dfc5274cd6fdfedee309ecdcbc2bf5cb82",
    "Command": "echo 1",
    "Created": 1367854155,
    "State": "Exited",
    "Status": "Exit 0",
    "Ports": [
      {
        "PrivatePort": 2222,
        "PublicPort": 3333,
        "Type": "tcp"
      }
    ],
    "Labels": {
      "com.example.vendor": "Acme",
      "com.example.license": "GPL",
      "com.example.version": "1.0"
    },
    "SizeRw": 12288,
    "SizeRootFs": 0,
    "HostConfig": {
      "NetworkMode": "default"
    },
    "NetworkSettings": {
      "Networks": {
        "bridge": {
          "NetworkID": "7ea29fc1412292a2d7bba362f9253545fecdfa8ce9a6e37dd10ba8bee7129812",
          "EndpointID": "2cdc4edb1ded3631c81f57966563e5c8525b81121bb3706a9a9a3ae102711f3f",
          "Gateway": "172.17.0.1",
          "IPAddress": "172.17.0.2",
          "IPPrefixLen": 16,
          "IPv6Gateway": "",
          "GlobalIPv6Address": "",
          "GlobalIPv6PrefixLen": 0,
          "MacAddress": "02:42:ac:11:00:02"
        }
      }
    },
    "Mounts": [
      {
        "Name": "fac362...80535",
        "Source": "/data",
        "Destination": "/data",
        "Driver": "local",
        "Mode": "ro,Z",
        "RW": false,
        "Propagation": ""
      }
    ]
  },
  {
    "Id": "9cd87474be90",
    "Names": [
      "/coolName"
    ],
    "Image": "ubuntu:latest",
    "ImageID": "d74508fb6632491cea586a1fd7d748dfc5274cd6fdfedee309ecdcbc2bf5cb82",
    "Command": "echo 222222",
    "Created": 1367854155,
    "State": "Exited",
    "Status": "Exit 0",
    "Ports": [],
    "Labels": {},
    "SizeRw": 12288,
    "SizeRootFs": 0,
    "HostConfig": {
      "NetworkMode": "default"
    },
    "NetworkSettings": {
      "Networks": {
        "bridge": {
          "NetworkID": "7ea29fc1412292a2d7bba362f9253545fecdfa8ce9a6e37dd10ba8bee7129812",
          "EndpointID": "88eaed7b37b38c2a3f0c4bc796494fdf51b270c2d22656412a2ca5d559a64d7a",
          "Gateway": "172.17.0.1",
          "IPAddress": "172.17.0.8",
          "IPPrefixLen": 16,
          "IPv6Gateway": "",
          "GlobalIPv6Address": "",
          "GlobalIPv6PrefixLen": 0,
          "MacAddress": "02:42:ac:11:00:08"
        }
      }
    },
    "Mounts": []
  },
  {
    "Id": "3176a2479c92",
    "Names": [
      "/sleepy_dog"
    ],
    "Image": "ubuntu:latest",
    "ImageID": "d74508fb6632491cea586a1fd7d748dfc5274cd6fdfedee309ecdcbc2bf5cb82",
    "Command": "echo 3333333333333333",
    "Created": 1367854154,
    "State": "Exited",
    "Status": "Exit 0",
    "Ports": [],
    "Labels": {},
    "SizeRw": 12288,
    "SizeRootFs": 0,
    "HostConfig": {
      "NetworkMode": "default"
    },
    "NetworkSettings": {
      "Networks": {
        "bridge": {
          "NetworkID": "7ea29fc1412292a2d7bba362f9253545fecdfa8ce9a6e37dd10ba8bee7129812",
          "EndpointID": "8b27c041c30326d59cd6e6f510d4f8d1d570a228466f956edf7815508f78e30d",
          "Gateway": "172.17.0.1",
          "IPAddress": "172.17.0.6",
          "IPPrefixLen": 16,
          "IPv6Gateway": "",
          "GlobalIPv6Address": "",
          "GlobalIPv6PrefixLen": 0,
          "MacAddress": "02:42:ac:11:00:06"
        }
      }
    },
    "Mounts": []
  },
  {
    "Id": "4cb07b47f9fb",
    "Names": [
      "/running_cat"
    ],
    "Image": "ubuntu:latest",
    "ImageID": "d74508fb6632491cea586a1fd7d748dfc5274cd6fdfedee309ecdcbc2bf5cb82",
    "Command": "echo 444444444444444444444444444444444",
    "Created": 1367854152,
    "State": "Exited",
    "Status": "Exit 0",
    "Ports": [],
    "Labels": {},
    "SizeRw": 12288,
    "SizeRootFs": 0,
    "HostConfig": {
      "NetworkMode": "default"
    },
    "NetworkSettings": {
      "Networks": {
        "bridge": {
          "NetworkID": "7ea29fc1412292a2d7bba362f9253545fecdfa8ce9a6e37dd10ba8bee7129812",
          "EndpointID": "d91c7b2f0644403d7ef3095985ea0e2370325cd2332ff3a3225c4247328e66e9",
          "Gateway": "172.17.0.1",
          "IPAddress": "172.17.0.5",
          "IPPrefixLen": 16,
          "IPv6Gateway": "",
          "GlobalIPv6Address": "",
          "GlobalIPv6PrefixLen": 0,
          "MacAddress": "02:42:ac:11:00:05"
        }
      }
    },
    "Mounts": []
  }
]
    ))
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
