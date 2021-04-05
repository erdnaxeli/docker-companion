require "clip"

require "./*"

module Companion::Commands
  abstract struct Command
    include Clip::Mapper

    Clip.add_commands(
      {
        "down"     => DownCommand,
        "images"   => ImagesCommand,
        "logs"     => LogsCommand,
        "networks" => NetworksCommand,
        "projects" => ProjectsCommand,
        "update"   => UpdateCommand,
      }
    )
  end

  @[Clip::Doc("Shutdown a project's services.")]
  struct DownCommand < Command
    include Clip::Mapper

    getter project : String
    @[Clip::Argument]
    getter services : Array(String)? = nil
  end

  @[Clip::Doc("List images.")]
  struct ImagesCommand < Command
    include Clip::Mapper
  end

  @[Clip::Doc("Get logs.")]
  struct LogsCommand < Command
    include Clip::Mapper

    getter project : String
    getter service : String
  end

  @[Clip::Doc("List networks.")]
  struct NetworksCommand < Command
    include Clip::Mapper
  end

  @[Clip::Doc("List projects.")]
  struct ProjectsCommand < Command
    include Clip::Mapper
  end

  @[Clip::Doc("Update a project.")]
  struct UpdateCommand < Command
    include Clip::Mapper

    getter project : String
    getter services : Array(String)
  end

  def self.dispatch(parameters : String)
    self.dispatch(Command.parse(parameters))
  end

  def self.dispatch(conn : Caridina::Connection, manager : Manager, room_id : String,
                    command)
    case command
    in Command::Help
      conn.send_message(room_id, Command.help(""))
    in DownCommand::Help
      conn.send_message(room_id, DownCommand.help("down"))
    in ImagesCommand::Help
      conn.send_message(room_id, ImagesCommand.help("images"))
    in LogsCommand::Help
      conn.send_message(room_id, LogsCommand.help("logs"))
    in NetworksCommand::Help
      conn.send_message(room_id, NetworksCommand.help("networks"))
    in ProjectsCommand::Help
      conn.send_message(room_id, ProjectsCommand.help("projects"))
    in UpdateCommand::Help
      conn.send_message(room_id, UpdateCommand.help("update"))
    in Command
      dispatch_command(conn, manager, room_id, command)
    end
  end

  def self.dispatch_command(conn : Caridina::Connection, manager : Manager, room_id : String,
                            command)
    case command
    in DownCommand
      Down.run(conn, manager, room_id, command)
    in ImagesCommand
      Images.run(conn, manager, room_id, command)
    in LogsCommand
      Logs.run(conn, manager, room_id, command)
    in NetworksCommand
      Networks.run(conn, manager, room_id, command)
    in ProjectsCommand
      Projects.run(conn, manager, room_id, command)
    in UpdateCommand
      Update.run(conn, manager, room_id, command)
    in Command
      raise "BUG: unreachable!"
    end
  end
end
