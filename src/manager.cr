require "./docker/client"
require "./docker/compose"
require "./project"

class Companion::Manager
  @projects = Hash(String, Project).new

  # Create an new Manager.
  def initialize(@docker : Docker::Client)
  end

  # Add a new project.
  #
  # The project must have a unique `name`, and `content` must be a some YAML
  # describing the project using docker-compose 3.8 format.
  def add_project(name : String, content : String)
    compose = Docker::Compose.from_yaml(content)

    if @projects.has_key? name
      raise "The projects #{name} already exists"
    end

    @projects[name] = Project.new(compose)
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

      @docker.create_container(options, container_name)
    end
  end

  # Pull images, creates and starts containers for the project *name*.
  def up(name : String)
    pull_images(name)
    create(name)
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
