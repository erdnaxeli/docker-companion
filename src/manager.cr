require "./docker/client"
require "./docker/compose"
require "./events"
require "./project"

require "path"

# Manage all docker operations.
#
# Some care must be taken for updates to be detected. At startup, the images
# state is saved. You can then add project.
#
# When upping a project, missing images will be pulled, but not new ones, and
# the images state will be refreshed.
#
# You should then run periodically `Companion::Manager#check_updates` which
# pulls all images and yield `Companion::UpdateEvent` for each service that can
# be updated.
class Companion::Manager
  record(
    ImageState,
    ids_history = Array(String).new,
    services = Set(Tuple(String, String)).new
  )

  getter images = Hash(String, ImageState).new { |h, k| h[k] = ImageState.new }
  getter networks = Array(Docker::Client::Network).new

  @projects = Hash(String, Project).new
  # A hash {project_name => {network_name, network_id}}
  @default_networks = Hash(String, Tuple(String, String)).new

  Log = Companion::Log.for(self)

  # Create an new Manager.
  def initialize(@docker : Docker::Client)
    refresh_images { }
    refresh_networks
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

    @projects[name] = project = Project.new(name, compose)

    if !working_directory.nil?
      project.fix_mounts(working_directory)
    end

    project.each_service do |service|
      @images[service.image].services << {name, service.name}
    end
  end

  # Creates missing containers for the project *name*.
  #
  # It pulls the image if needed. If the container are already there, it does
  # not recreate them even if their config changed.
  def create(name : String) : Nil
    project = get_project(name)
    network_name, network_id = create_default_network(project)
    @default_networks[name] = {network_name, network_id}

    project.each_service do |service|
      create_container(name, service)
    end
  end

  def create_container(project_name : String, service : Companion::Docker::Compose::Service) : String
    if !@images.has_key?(service.image)
      pull_image(service.image)
    end

    container_name = get_container_name(project_name, service)
    options = Docker::Client::CreateContainerOptions.new
    options.image = service.image
    options.labels = service.labels
    service.env.try &.each { |k, v| options.env[k] = v }

    add_ports(service, options)
    add_volumes(service, options.host_config)
    additional_networks = add_networks(
      project_name,
      service,
      options.networking_config.endpoints_config,
    )

    begin
      response = @docker.create_container(options, container_name)
    rescue Docker::Client::ConflictException
      if id = @docker.get_container_id(container_name)
        return id
      else
        raise "Error while creating the container: docker complains about a conflict but we can't found the conflicting container"
      end
    end

    if container_id = response.id
      additional_networks.each do |endpoint|
        options = Docker::Client::ConnectNetworkOptions.new
        options.container = container_id
        options.endpoint_config = endpoint

        @docker.connect_network(options)
      end
    else
      raise "Error while creating container #{container_name}: #{response.message}"
    end

    container_id
  end

  # Kills and removes all containers for the project *name*.
  def down(name : String) : Nil
    project = get_project(name)
    project.each_service do |service|
      remove_container(name, service)
    end
  end

  # Kills and removes the service *service_name* container for the project *project_name*.
  def down_service(project_name : String, service_name : String) : Nil
    project = get_project(project_name)
    project.each_service do |service|
      if service.name == service_name
        remove_container(project_name, service)
      end
    end
  end

  # Returns an iterator over the projects' names.
  def each_projects
    @projects.each_key
  end

  # Creates and starts containers for the project *name*.
  def up(name : String)
    create(name)
    start(name)
    refresh_images { }
  end

  # Creates and starts the service *service_name* container for project *project_name*.
  #
  # It does not pull the image.
  def up_service(project_name : String, service_name : String) : Nil
    get_project(project_name).each_service do |service|
      if service.name == service_name
        id = create_container(project_name, service)
        @docker.start_container(id)
      end
    end
  end

  # Pull an image.
  #
  # The image name can contains a tag in the form "image:tag", and even a
  # registry in the form "regitry/image:tag".
  def pull_image(image : String) : Nil
    Log.info &.emit("Pulling image", image: image)
    parts = image.split(":")
    if parts.size == 1
      @docker.pull_image(image) { }
    else
      @docker.pull_image(parts[0], parts[1]) { }
    end
  end

  # Pulls the docker images for the project *name*.
  def pull_images(name : String) : Nil
    project = get_project(name)
    project.each_image { |image| pull_image(image) }
  end

  # Starts all the containers for the project *name*.
  #
  # If a container is already running, it does nothing.
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

  # Checks if there are images update.
  #
  # If an update is found, the block is called with an event indicating the
  # image name and the projects's containers concerned.
  def check_updates(&block : UpdateEvent ->) : Nil
    @images.each do |tag, image|
      if image.services.size > 0
        pull_image(tag)
      end
    end
    refresh_images do |tag|
      @images[tag].services.each do |project, service|
        yield UpdateEvent.new(
          image: tag,
          project: project,
          service: service,
        )
      end
    end
  end

  # Add service's networks to endpoints_config.
  #
  # As Docker allow to specify only one network at the container creation, the
  # other ones are returned in an array and the container must be connected to
  # them.
  private def add_networks(project_name, service, endpoints_config)
    default_network_name, default_network_id = @default_networks[project_name]
    additional_networks = Array(Docker::Client::CreateContainerOptions::EndpointConfig).new

    if networks = service.networks
      networks.each do |network|
        endpoint_config = Docker::Client::CreateContainerOptions::EndpointConfig.new
        endpoint_config.aliases = [service.name]

        if network == "default"
          endpoint_config.network_id = default_network_id

          if endpoints_config.size == 0
            endpoints_config[default_network_name] = endpoint_config
          else
            additional_networks << endpoint_config
          end
        elsif id = get_network_id(network)
          endpoint_config.network_id = id

          if endpoints_config.size == 0
            endpoints_config[network] = endpoint_config
          else
            additional_networks << endpoint_config
          end
        else
          raise "Unknown network #{network}"
        end
      end
    else
      # Add default network
      endpoint_config = Docker::Client::CreateContainerOptions::EndpointConfig.new
      endpoint_config.aliases = [service.name]
      endpoint_config.network_id = default_network_id
      endpoints_config[default_network_name] = endpoint_config
    end

    additional_networks
  end

  private def add_ports(service, options) : Nil
    host_config = options.host_config

    service.ports.each do |port|
      binding = Docker::Client::CreateContainerOptions::HostConfig::PortBinding.new

      if host_ip = port.host_ip
        binding.host_ip = host_ip
      end

      if host_port = port.host_port
        binding.host_port = host_port.to_s
      end

      key = "#{port.container_port}/tcp"
      if !host_config.port_bindings.has_key?(key)
        host_config.port_bindings[key] = Array(Docker::Client::CreateContainerOptions::HostConfig::PortBinding).new
      end

      host_config.port_bindings[key] << binding
      options.exposed_ports << port.container_port
    end
  end

  private def add_volumes(service, host_config) : Nil
    service.volumes.each do |volume|
      mount = Docker::Client::CreateContainerOptions::HostConfig::Mount.new

      if source = volume.source
        mount.type = Docker::Client::CreateContainerOptions::HostConfig::Mount::Type::Bind
        mount.source = source
      end

      mount.target = volume.target
      host_config.mounts << mount
    end

    host_config.restart_policy.name = case service.restart
                                      in Docker::Compose::Service::RestartPolicy::No
                                        Docker::Client::CreateContainerOptions::HostConfig::RestartPolicy::Name::No
                                      in Docker::Compose::Service::RestartPolicy::Always
                                        Docker::Client::CreateContainerOptions::HostConfig::RestartPolicy::Name::Always
                                      in Docker::Compose::Service::RestartPolicy::OnFailure
                                        Docker::Client::CreateContainerOptions::HostConfig::RestartPolicy::Name::OnFailure
                                      in Docker::Compose::Service::RestartPolicy::UnlessStopped
                                        Docker::Client::CreateContainerOptions::HostConfig::RestartPolicy::Name::UnlessStopped
                                      end
  end

  # Creates a network if it does not exists.
  private def create_default_network(project)
    name = "#{project.name}_network"

    id = get_network_id(name)
    if id.nil?
      options = Docker::Client::CreateNetworkOptions.new
      options.name = name
      response = @docker.create_network(options)
      id = response.id
    end

    {name, id}
  end

  private def get_container_name(project_name, service)
    service.container_name || "#{project_name}_#{service.name}"
  end

  private def get_network_id(name)
    if network = @networks.find { |n| n.name == name }
      network.id
    end
  end

  private def get_project(name)
    if !@projects.has_key? name
      raise "Unknown project #{name}"
    end

    @projects[name]
  end

  private def refresh_images : Nil
    Log.info { "Refreshing images" }
    @docker.images.each do |image|
      image.repo_tags.try &.each do |tag|
        image_state = @images[tag]
        if (last_id = image_state.ids_history[0]?) != image.id
          image_state.ids_history.unshift(image.id)

          # We don't yield if it's the first time we see this image.
          if !last_id.nil?
            yield tag
          end
        end
      end
    end

    Log.info &.emit("Images refreshed", images: images.size)
  end

  private def refresh_networks : Nil
    Log.info { "Refreshing networks" }
    @networks = @docker.networks
  end

  private def remove_container(project_name, service) : Nil
    container_name = get_container_name(project_name, service)
    if id = @docker.get_container_id(container_name)
      @docker.remove_container(id)
    end
  end
end
