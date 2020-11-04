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

  it "creates all containers for a project" do
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

    DOCKER.reset
    manager.create("test")

    DOCKER.create_container_calls.size.should eq(2)
    DOCKER.create_container_calls[0][:options].image.should eq("bash:latest")
    DOCKER.create_container_calls[0][:name].should eq("test_test")
    DOCKER.create_container_calls[1][:options].image.should eq("python:3.8")
    DOCKER.create_container_calls[1][:name].should eq("test_tada")
  end

  it "creates a container with all options" do
    manager = Companion::Manager.new(DOCKER)
    manager.add_project(
      "test",
      %(
        version: "3.8"
        services:
          test:
            container_name: not_a_test
            image: bash:latest
            restart: unless-stopped
            ports:
              - 127.0.0.1:42:51
            volumes:
              - ./data:/data
            labels:
              traefik.http.routers.test.entrypoints: https
              traefik.http.routers.test.tls.certresolver: letsencrypt
            environment:
              PASSWORD: secretword
          othertest:
            image: bash:latest
            networks:
              - othernetwork
              - default
          nonet:
            image: bash:latest
            networks: []
      )
    )

    DOCKER.reset
    manager.create("test")

    DOCKER.create_container_calls.size.should eq(3)

    # Test first container

    call = DOCKER.create_container_calls[0]
    call[:name].should eq ("not_a_test")
    options = call[:options]
    options.image.should eq("bash:latest")
    options.env.should eq({"PASSWORD" => "secretword"})
    options.labels.should eq (
      {
        "traefik.http.routers.test.entrypoints"      => "https",
        "traefik.http.routers.test.tls.certresolver" => "letsencrypt",
      }
    )

    options.host_config.mounts.size.should eq(1)
    mount = options.host_config.mounts[0]
    mount.target.should eq("/data")
    mount.source.should eq("./data")
    mount.type.should eq(Companion::Docker::Client::CreateContainerOptions::HostConfig::Mount::Type::Bind)

    options.host_config.restart_policy.name.should eq(Companion::Docker::Client::CreateContainerOptions::HostConfig::RestartPolicy::Name::UnlessStopped)

    options.host_config.port_bindings.size.should eq(1)
    key = options.host_config.port_bindings.first_key
    key.should eq("51/tcp")

    options.host_config.port_bindings[key].size.should eq(1)
    port_binding = options.host_config.port_bindings[key][0]
    port_binding.host_ip.should eq("127.0.0.1")
    port_binding.host_port.should eq("42")

    options.networking_config.endpoints_config.size.should eq(1)
    endpoints_config = options.networking_config.endpoints_config
    endpoints_config.first_key.should eq("test_network")
    endpoints_config.first_value.aliases.should eq(["test"])
    endpoints_config.first_value.network_id.should eq("test_network_id")

    #  Test second container

    call = DOCKER.create_container_calls[1]
    call[:name].should eq("test_othertest")
    options = call[:options]
    options.image.should eq("bash:latest")
    options.networking_config.endpoints_config.size.should eq(2)
    endpoints_config = options.networking_config.endpoints_config
    endpoints_config.keys.should eq(["othernetwork", "test_network"])
    endpoints_config["othernetwork"].aliases.should eq(["othertest"])
    endpoints_config["othernetwork"].network_id.should eq("othernetwork_id")
    endpoints_config["test_network"].aliases.should eq(["othertest"])
    endpoints_config["test_network"].network_id.should eq("test_network_id")

    #  Test third container

    call = DOCKER.create_container_calls[2]
    call[:name].should eq("test_nonet")
    options = call[:options]
    options.image.should eq("bash:latest")
    options.networking_config.endpoints_config.size.should eq(0)
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
