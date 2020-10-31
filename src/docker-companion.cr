require "./docker/client"
require "./docker/compose"
require "./manager"

require "caridina"
require "parameters"

require "dir"
require "file"
require "option_parser"
require "path"
require "yaml"

module Companion
  VERSION = "0.1.0"

  Log = ::Log.for(self)

  struct Config
    include YAML::Serializable

    struct Matrix
      include YAML::Serializable

      property homeserver : String
      property access_token : String
    end

    property matrix : Matrix
    property users : Array(String)
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
    channel = Channel(Caridina::Events::Sync).new
    conn.sync(channel)

    Log.info { "Adding project" }
    manager = Manager.new(Docker::Client::Local.new)

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
      manager.up(name)
    end

    loop do
      sync = channel.receive
      sync.room_events do |event|
        if (message = event.message?) && event.sender != conn.user_id && config.users.includes? event.sender
          if parameters = Parameters.parse(message.body)
            OptionParser.parse(parameters) do |parser|
              parser.banner = "COMMAND [OPTIONS]"
              parser.on("list", "list projects") do
                msg = String.build do |str|
                  str << "* " << manager.each_projects.join("\n *")
                end

                conn.send_message(event.room_id, msg)
              end
              parser.invalid_option { }
              parser.unknown_args { conn.send_message(event.room_id, parser.to_s) }
            end
          end
        end
      end
    end
  end
end
