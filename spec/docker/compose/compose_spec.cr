require "./spec_helper"

describe Companion::Docker::Compose do
  it "deserializes YAML" do
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
end

describe Companion::Docker::Compose::Service::Port do
  it "supports 'container'" do
    port = Companion::Docker::Compose::Service::Port.new("42")
    port.host.should be_nil
    port.container.should eq(42)
  end

  it "supports 'host:container'" do
    port = Companion::Docker::Compose::Service::Port.new("42:51")
    port.host.should eq(42)
    port.container.should eq(51)
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
