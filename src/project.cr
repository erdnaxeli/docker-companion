require "./docker/compose"

class Companion::Project
  getter compose : Companion::Docker::Compose

  def initialize(@compose)
  end

  def each_image
    each_service do |service|
      yield service.image
    end
  end

  def each_service
    compose.services.each { |s| yield s }
  end
end
