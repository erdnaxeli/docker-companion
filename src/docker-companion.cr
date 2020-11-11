require "./bot"
require "./docker/client"
require "./docker/compose"
require "./manager"

require "caridina"
require "parameters"

require "dir"
require "file"
require "option_parser"
require "path"
require "time"
require "yaml"

module Companion
  VERSION = "0.1.0"

  Log = ::Log.for(self)

  struct Config
    include YAML::Serializable

    struct Matrix
      include YAML::Serializable

      getter access_token : String
      getter homeserver : String
      getter notification_room : String
      getter users : Array(String)
    end

    getter matrix : Matrix
  end

  def self.read_config(filename = "config.yaml") : Config
    content = File.read(filename)
    Config.from_yaml(content)
  end

  def self.run : Nil
    Log.info { "Read configuration" }
    config = read_config

    Log.info { "Connecting to Matrix" }
    conn = Caridina::ConnectionImpl.new(
      config.matrix.homeserver,
      config.matrix.access_token,
    )

    manager = Manager.new(Docker::Client::Local.new)
    add_projects(manager)

    matrix = Channel(Caridina::Events::Sync).new
    conn.sync(matrix)

    bot = Bot.new(config.matrix.users, conn, manager)

    update = Channel(Nil).new
    spawn do
      loop do
        update.send nil
        sleep 1.hour
      end
    end

    loop do
      select
      when sync = matrix.receive
        bot.exec(sync)
      when update.receive
        manager.check_updates do |event|
          conn.send_message(
            config.matrix.notification_room,
            %(A new image "#{event.image}" was pulled. To use it, run the command `update #{event.project} #{event.service}`.),
            %(A new image "#{event.image}" was pulled. To use it, run the command <code>update #{event.project} #{event.service}</code>.)
          )
        end
      end
    end
  end

  def self.add_projects(manager : Manager) : Nil
    Log.info { "Adding projects" }
    Dir.new(Dir.current).each_child do |name|
      if !File.directory?(name)
        next
      end

      path = Path[name] / "docker-compose.yaml"
      if !File.file?(path)
        next
      end

      Log.info &.emit("Add project", project_name: name)
      content = File.read(path)
      manager.add_project(name, content, Path[Dir.current] / name)

      Log.info &.emit("Starting project", project_name: name)
      # As we don't know (yet) if the currently running containers are correctly
      # configured, we just shut them down and create new ones.
      #
      # TODO: do that in a better way
      manager.down(name)
      manager.up(name)
    end
  end

  def self.exec_matrix(sync : Caridina::Events::Sync, config : Config, conn : Caridina::Connection, manager : Manager) : Nil
  end
end
