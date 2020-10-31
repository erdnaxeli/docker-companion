require "./docker/client"
require "./docker/compose"
require "./project"

require "path"

class Companion::Manager
  @images = Hash(String, String?)
  @tags = Hash(String, String)
  @projects = Hash(String, Project).new

  # Create an new Manager.
  def initialize(@docker : Docker::Client)
    # Get images
    # * fill @images
    # * fill @tags
  end

  # Add a new project.
  #
  # The project must have a unique *name*, and *content* must be a some YAML
  # describing the project using docker-compose 3.8 format.
  # *working_directory* must be the project's directory. It is used to find bind
  # mounts.
  def add_project(name : String, content : String, working_directory : Path? = nil)
    compose = Docker::Compose.from_yaml(content)

    if @projects.has_key? name
      raise "The projects #{name} already exists"
    end

    @projects[name] = Project.new(compose)

    if !working_directory.nil?
      @projects[name].fix_mounts(working_directory)
    end
  end

  # Creates missing containers for the project *name*.
  #
  # If the container are already there, it does not recreate them even if their
  # config changed. It does not pull images neither, it must have been done with
  # `#pull_images`.
  def create(name : String)
    project = get_project(name)

    project.each_service do |service|
      container_name = get_container_name(name, service)
      options = Docker::CreateContainerOptions.new
      options.image = service.image
      host_config = options.host_config = Docker::CreateContainerOptions::HostConfig.new

      service.ports.each do |port|
        binding = Docker::CreateContainerOptions::HostConfig::PortBinding.new

        if host_ip = port.host_ip
          binding.host_ip = host_ip
        end

        if host_port = port.host_port
          binding.host_port = host_port.to_s
        end

        key = "#{port.container_port}/tcp"
        if !host_config.port_bindings.has_key?(key)
          host_config.port_bindings[key] = Array(Docker::CreateContainerOptions::HostConfig::PortBinding).new
        end

        host_config.port_bindings[key] << binding
      end

      service.volumes.each do |volume|
        mount = Docker::CreateContainerOptions::HostConfig::Mount.new

        if source = volume.source
          mount.type = Docker::CreateContainerOptions::HostConfig::Mount::Type::Bind
          mount.source = source
        end

        mount.target = volume.target
        host_config.mounts << mount
      end

      host_config.restart_policy.name = case service.restart
                                        in Docker::Compose::Service::RestartPolicy::No
                                          Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::No
                                        in Docker::Compose::Service::RestartPolicy::Always
                                          Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::Always
                                        in Docker::Compose::Service::RestartPolicy::OnFailure
                                          Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::OnFailure
                                        in Docker::Compose::Service::RestartPolicy::UnlessStopped
                                          Docker::CreateContainerOptions::HostConfig::RestartPolicy::Name::UnlessStopped
                                        end

      @docker.create_container(options, container_name)
    end
  end

  # Return an iterator over the projects' names.
  def each_projects
    @projects.each_key
  end

  # Pull images, creates and starts containers for the project *name*.
  def up(name : String)
    pull_images(name)

    begin
      create(name)
    rescue Docker::ConflictException
    end

    start(name)
  end

  # Pull the docker images for the project *name*.
  def pull_images(name : String)
    project = get_project(name)
    project.each_image do |image|
      @docker.pull_image(image) { }
    end
  end

  # Start the project *name*.
  def start(name : String)
    project = get_project(name)
    project.each_service do |service|
      container_name = get_container_name(name, service)
      container_id = @docker.get_container_id(container_name)

      if id = container_id
        @docker.start_container(id)
      else
        raise "Unknown container #{container_name}"
      end
    end
  end

  private def get_container_name(project_name, service)
    service.container_name || "#{project_name}_#{service.name}"
  end

  private def get_project(name)
    if !@projects.has_key? name
      raise "Unknown project #{name}"
    end

    @projects[name]
  end
end
