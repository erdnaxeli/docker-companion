require "clip"

abstract struct Companion::Commands::Command
  include Clip::Mapper

  Clip.add_commands(
    {
      "down"     => Down,
      "images"   => Images,
      "logs"     => Logs,
      "networks" => Networks,
      "projects" => Projects,
      "update"   => Update,
    }
  )

  abstract def run(conn : Caridina::Connection, manager : Manager, room_id : String)
end
