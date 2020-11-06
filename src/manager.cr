require "./docker/client"
require "./docker/compose"
require "./events"
require "./project"

require "path"

class Companion::Manager
  getter images = Array(Docker::Client::Image).new
  getter networks = Array(Docker::Client::Network).new

  # A hash {image id => [images tags]}
  @images_ids = Hash(String, Array(String)?).new
  # A hash {image tag => [history of images ids]}
  @images_tags = Hash(String, Array(String)).new { |h, k| h[k] = Array(String).new }
  @projects = Hash(String, Project).new

  Log = Companion::Log.for(self)

  # Create an new Manager.
  def initialize(@docker : Docker::Client)
    refresh_images
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

    @projects[name] = Project.new(name, compose)

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
    network_name, network_id = create_default_network(project)

    project.each_service do |service|
      container_name = get_container_name(name, service)
      options = Docker::Client::CreateContainerOptions.new
      options.image = service.image
      options.labels = service.labels
      service.env.try &.each { |k, v| options.env[k] = v }

      add_ports(service, options)
      add_volumes(service, options.host_config)
      additional_networks = add_networks(
        service,
        options.networking_config.endpoints_config,
        network_name,
        network_id,
      )

      begin
        response = @docker.create_container(options, container_name)
      rescue Docker::Client::ConflictException
        return
      end

      if container_id = response.id
        additional_networks.each do |endpoint|
          options = Docker::Client::ConnectNetworkOptions.new
          options.container = container_id
          options.endpoint_config = endpoint

          @docker.connect_network(options)
        end
      end
    end
  end

  # Kiils and removes all containers for the project *name*.
  def down(name : String)
    project = get_project(name)
    project.each_service do |service|
      container_name = get_container_name(name, service)
      if id = @docker.get_container_id(container_name)
        @docker.remove_container(id)
      end
    end
  end

  # Returns an iterator over the projects' names.
  def each_projects
    @projects.each_key
  end

  # Pulls images, creates and starts containers for the project *name*.
  def up(name : String)
    pull_images(name)
    create(name)
    start(name)
  end

  # Pull an image.
  #
  # The image name can contains a tag in the form "image:tag", and even a
  # registry in the form "regitry/image:tag".
  def pull_image(image : String)
    parts = image.split(":")
    if parts.size == 1
      @docker.pull_image(image) { }
    else
      @docker.pull_image(parts[0], parts[1]) { }
    end
  end

  # Pulls the docker images for the project *name*.
  def pull_images(name : String)
    project = get_project(name)
    project.each_image { |image| pull_image(image) }
    refresh_images
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

  record ImageState, image_id : String, services = Array(Tuple(String, String)).new

  # This methods watch for any image update.
  #
  # If an update is found, the block is called with an event indicating the
  # image name and the projects's containers concerned.
  def watch_updates(&block : UpdateEvent ->)
    state = Hash(String, ImageState).new do |h, k|
      # we take the last known id
      image_id = @images_tags[k][0]
      h[k] = ImageState.new(image_id: image_id)
    end

    @projects.each do |name, project|
      project.each_service do |service|
        state[service.image].services << {name, service.name}
      end
    end

    loop do
      state.each_key do |image|
        pull_image(image)
      end
      refresh_images

      state.each do |image_tag, image_state|
        last_known_id = @images_tags[image_tag][0]
        if image_state.image_id == last_known_id
          next
        end

        image_state.services.each do |project, container|
          yield UpdateEvent.new(
            container: container,
            image: image_tag,
            project: project,
          )
          state[image_tag] = ImageState.new(
            image_id: last_known_id,
            services: image_state.services,
          )
        end
      end

      sleep 30.seconds
    end
  end

  # Add service's networks to endpoints_config.
  #
  # As Docker allow to specify only one network at the container creation, the
  # other ones are returned in an array and the container must be connected to
  # them.
  private def add_networks(service, endpoints_config, default_network_name, default_network_id)
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
    @images = @docker.images

    @images.each do |image|
      @images_ids[image.id] = image.repo_tags
      image.repo_tags.try &.each do |tag|
        if @images_tags[tag].size == 0 || @images_tags[tag][0] != image.id
          @images_tags[tag].unshift(image.id)
        end
      end
    end

    Log.info &.emit("Images refreshed", images: images.size)
  end

  private def refresh_networks : Nil
    Log.info { "Refreshing networks" }
    @networks = @docker.networks
  end
end
