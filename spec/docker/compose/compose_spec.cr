require "./spec_helper"

describe Companion::Docker::Compose do
  it "deserializes YAML from docker doc" do
    Companion::Docker::Compose.from_yaml(%{
            version: "3.8"
            services:

              redis:
                image: redis:alpine
                ports:
                  - "6379"
                networks:
                  - frontend
                deploy:
                  replicas: 2
                  update_config:
                    parallelism: 2
                    delay: 10s
                  restart_policy:
                    condition: on-failure

              db:
                image: postgres:9.4
                volumes:
                  - db-data:/var/lib/postgresql/data
                networks:
                  - backend
                deploy:
                  placement:
                    max_replicas_per_node: 1
                    constraints:
                      - "node.role==manager"

              vote:
                image: dockersamples/examplevotingapp_vote:before
                ports:
                  - "5000:80"
                networks:
                  - frontend
                depends_on:
                  - redis
                deploy:
                  replicas: 2
                  update_config:
                    parallelism: 2
                  restart_policy:
                    condition: on-failure

              result:
                image: dockersamples/examplevotingapp_result:before
                ports:
                  - "5001:80"
                networks:
                  - backend
                depends_on:
                  - db
                deploy:
                  replicas: 1
                  update_config:
                    parallelism: 2
                    delay: 10s
                  restart_policy:
                    condition: on-failure

              worker:
                image: dockersamples/examplevotingapp_worker
                networks:
                  - frontend
                  - backend
                deploy:
                  mode: replicated
                  replicas: 1
                  labels: [APP=VOTING]
                  restart_policy:
                    condition: on-failure
                    delay: 10s
                    max_attempts: 3
                    window: 120s
                  placement:
                    constraints:
                      - "node.role==manager"

              visualizer:
                image: dockersamples/visualizer:stable
                ports:
                  - "8080:8080"
                stop_grace_period: 1m30s
                volumes:
                  - "/var/run/docker.sock:/var/run/docker.sock"
                deploy:
                  placement:
                    constraints:
                      - "node.role==manager"

            networks:
              frontend:
              backend:

            volumes:
              db-data:
        })
  end

  it "correctly deserializes YAML" do
    compose = Companion::Docker::Compose.from_yaml(%{
version: "3.8"

services:
  matrix-appservice-slack:
    container_name: matrix-appservice-slack
    #image: matrixdotorg/matrix-appservice-slack:release-1.4.0
    image: matrixdotorg/matrix-appservice-slack:latest
    #build: .
    restart: unless-stopped
    ports:
      - 127.0.0.1:5858:5858
    volumes:
      - ./matrix-appservice-slack/config:/config
    networks:
      - default
      - gateway
    labels:
      traefik.enable: true
      traefik.http.services.slack.loadbalancer.server.port: 9899

networks:
  gateway:
    external: true
    })

    compose.services.size.should eq(1)
    service = compose.services[0]
    service.name.should eq("matrix-appservice-slack")
    service.image.should eq("matrixdotorg/matrix-appservice-slack:latest")
    service.restart.should eq(Companion::Docker::Compose::Service::RestartPolicy::UnlessStopped)

    service.ports.size.should eq(1)
    port = service.ports[0]
    port.host_ip.should eq("127.0.0.1")
    port.host_port.should eq(5858)
    port.container_port.should eq(5858)

    service.volumes.size.should eq(1)
    volume = service.volumes[0]
    volume.source.should eq("./matrix-appservice-slack/config")
    volume.target.should eq("/config")

    service.networks.should eq(["default", "gateway"])
    service.labels.should eq(
      {
        "traefik.enable"                                       => "true",
        "traefik.http.services.slack.loadbalancer.server.port" => "9899",
      }
    )
  end

  it "checks image presence" do
    expect_raises(Exception, "You must provide an image name") do
      Companion::Docker::Compose.from_yaml(%(
version: "3.8"
services:
  test:
       ))
    end
  end

  it "checks correct version" do
    expect_raises(Exception, "Unsupported version '3.7'") do
      Companion::Docker::Compose.from_yaml(%(
version: "3.7"
services:
  test:
    image: test:latest
        ))
    end
  end

  it "checks restart policy" do
    expect_raises(Exception, "Unknown value 'tada' for restart policy") do
      Companion::Docker::Compose.from_yaml(%(
version: "3.8"
services:
  test:
    image: test:latest
    restart: tada
        ))
    end
  end
end

describe Companion::Docker::Compose::Service::Port do
  it "supports 'container'" do
    port = Companion::Docker::Compose::Service::Port.new("42")
    port.host_ip.should be_nil
    port.host_port.should be_nil
    port.container_port.should eq(42)
  end

  it "supports 'host:container'" do
    port = Companion::Docker::Compose::Service::Port.new("42:51")
    port.host_ip.should be_nil
    port.host_port.should eq(42)
    port.container_port.should eq(51)
  end

  it "supports 'ip:host:container'" do
    port = Companion::Docker::Compose::Service::Port.new("127.0.0.1:42:51")
    port.host_ip.should eq("127.0.0.1")
    port.host_port.should eq(42)
    port.container_port.should eq(51)
  end
end

describe Companion::Docker::Compose::Service::Volume do
  it "supports 'target'" do
    volume = Companion::Docker::Compose::Service::Volume.new("/home")
    volume.source.should be_nil
    volume.target.should eq("/home")
    volume.mode.should eq(Companion::Docker::Compose::Service::Volume::Mode::RW)
  end

  it "supports 'source:target'" do
    volume = Companion::Docker::Compose::Service::Volume.new("/var/home:/home")
    volume.source.should eq("/var/home")
    volume.target.should eq("/home")
    volume.mode.should eq(Companion::Docker::Compose::Service::Volume::Mode::RW)
  end

  it "supports 'source:target:mode'" do
    volume = Companion::Docker::Compose::Service::Volume.new("/var/home:/home:ro")
    volume.source.should eq("/var/home")
    volume.target.should eq("/home")
    volume.mode.should eq(Companion::Docker::Compose::Service::Volume::Mode::RO)
  end
end
