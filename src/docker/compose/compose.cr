require "./file"

class Companion::Docker::Compose
  @services = Array(Service).new

  def self.from_yaml(yaml)
    new(yaml)
  end

  def initialize(yaml)
    file = File.from_yaml(yaml)

    if file.version != "3.8"
      raise "Unsuported version '#{file.version}'"
    end

    file.services.each do |name, service|
      @services << Service.new(name, service)
    end
  end
end

class Companion::Docker::Compose::Service
  getter name : String

  @build : String?
  @container_name : String?
  @image : String?
  @labels : Array(String)?
  @networks : Array(String)?
  @restart = RestartPolicy::No
  @ports = Array(Port).new
  @volumes = Array(Volume).new

  def initialize(@name, service : File::Service)
    @build = service.build
    @container_name = service.container_name
    @image = service.image
    @labels = service.labels
    @networks = service.networks

    if restart = service.restart
      @restart = case restart
                 when "no"
                   RestartPolicy::No
                 when "always"
                   RestartPolicy::Always
                 when "on-failure"
                   RestartPolicy::OnFailure
                 when "unless-stopped"
                   RestartPolicy::UnlessStopped
                 else
                   raise "Unknown value '#{restart}' for restart policy"
                 end
    end

    if ports = service.ports
      ports.each do |port|
        @ports << Port.new(port)
      end
    end

    if volumes = service.volumes
      volumes.each do |volume|
        @volumes << Volume.new(volume)
      end
    end
  end
end

enum Companion::Docker::Compose::Service::RestartPolicy
  No
  Always
  OnFailure
  UnlessStopped
end

class Companion::Docker::Compose::Service::Port
  getter host : Int16?
  getter container : Int16

  def initialize(str : String)
    parts = str.split(":")
    case parts.size
    when 1
      @container = parts[0].to_i16
    when 2
      @host = parts[0].to_i16
      @container = parts[1].to_i16
    else
      raise "Invalid port mapping description '#{str}'"
    end
  end
end

class Companion::Docker::Compose::Service::Volume
  enum Mode
    RO
    RW
  end

  getter source : String?
  getter target : String
  getter mode = Mode::RW

  def initialize(str : String)
    parts = str.split(":")
    case parts.size
    when 1
      @target = parts[0]
    when 2
      @source = parts[0]
      @target = parts[1]
    when 3
      @source = parts[0]
      @target = parts[1]
      @mode = Mode.parse(parts[2])
    else
      raise "Unknown volume mapping description '#{str}'"
    end
  end
end
