require "./docker/compose"

require "path"

class Companion::Project
  getter name : String
  getter compose : Companion::Docker::Compose

  def initialize(@name, @compose)
  end

  def each_image
    each_service do |service|
      yield service.image
    end
  end

  def each_service
    compose.services.each { |s| yield s }
  end

  # Converts relative paths to absolute paths in bind mounts.
  def fix_mounts(working_directory : Path)
    each_service do |service|
      service.volumes.each &.fix_local_source(working_directory)
    end
  end
end
