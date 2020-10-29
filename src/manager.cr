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
      container_name = service.container_name || "#{name}_#{service.name}"
      container_id = @docker.get_container_id(container_name)

      if id = container_id
        @docker.start_container(id)
      else
        raise "Unknown container #{container_name}"
      end
    end
  end

  private def get_project(name)
    if !@projects.has_key? name
      raise "Unknown project #{name}"
    end

    @projects[name]
  end
end
