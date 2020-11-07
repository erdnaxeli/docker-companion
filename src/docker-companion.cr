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
    end

    getter matrix : Matrix
    getter users : Array(String)
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
    spawn listen_matrix(config, conn, manager)
    add_projects(manager)

    manager.watch_updates do |event|
      conn.send_message(
        config.matrix.notification_room,
        %(A new image "#{event.image}" was pulled. To use it, run the command `update #{event.project} #{event.service}`.),
        %(A new image "#{event.image}" was pulled. To use it, run the command <code>update #{event.project} #{event.service}</code>.)
      )
    end

    sleep
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

  def self.listen_matrix(config : Config, conn : Caridina::Connection, manager : Manager) : Nil
    channel = Channel(Caridina::Events::Sync).new
    conn.sync(channel)
    first_sync = true

    loop do
      sync = channel.receive
      sync.invites do |event|
        conn.join(event.room_id)
        conn.send_message(
          event.room_id,
          "Hi! I am your new companion, here to help you manage your docker services. Try the 'help' command to begin."
        )
      end

      if first_sync
        # Skip the first sync messages as it can contains messages already read.
        first_sync = false
        next
      end

      sync.room_events do |event|
        if (message = event.message?) && event.sender != conn.user_id && config.users.includes? event.sender
          if parameters = Parameters.parse(message.body)
            puts parameters
            OptionParser.parse(parameters) do |parser|
              parser.banner = "COMMAND [OPTIONS]"
              parser.on("projects", "list projects") do
                msg = String.build do |str|
                  str << "* " << manager.each_projects.join("\n* ")
                end

                conn.send_message(event.room_id, msg)
              end
              parser.on("images", "list images") do
                msg = String.build do |str|
                  str << "* " << manager.images.map { |t, i| %(#{t} #{i.ids_history[0]?}) }.join("\n* ")
                end

                conn.send_message(event.room_id, msg)
              end
              parser.on("networks", "list networks") do
                msg = String.build do |str|
                  str << "* " << manager.networks.map { |n| %(#{n.name} #{n.id}) }.join("\n* ")
                end

                conn.send_message(event.room_id, msg)
              end
              parser.on("update", "update a project") do
                parser.banner = "update PROJECT [SERVICES]"

                parser.unknown_args do |args|
                  if args.size > 0
                    project = args.shift
                    services = args

                    if services.empty?
                      conn.send_message(event.room_id, "You need to provide at least one service to update")
                      next
                    end

                    services.each do |service|
                      msg_id = ""
                      begin
                        elapsed_time = Time.measure do
                          msg_id = conn.send_message(event.room_id, "Removing the container...")
                          manager.down_service(project, service)
                          conn.edit_message(event.room_id, msg_id, "Recreating the container...")
                          manager.up_service(project, service)
                        end
                        time = if elapsed_time < 2.seconds
                                 "#{elapsed_time.milliseconds}ms"
                               else
                                 "#{elapsed_time.seconds}s"
                               end

                        conn.edit_message(
                          event.room_id,
                          msg_id,
                          "Service #{service} of project #{project} is up to date! (it tooks #{time})",
                        )
                      rescue ex
                        puts ex.message
                      end
                    end
                  else
                    conn.send_message(event.room_id, "You need to provide a project")
                  end
                end
              end
              parser.on("-h", "--help", "show this help") do
                conn.send_message(event.room_id, parser.to_s)
              end
              parser.invalid_option { }
              parser.unknown_args do |args|
                if args.size > 0 && args[0] == "help"
                  conn.send_message(event.room_id, parser.to_s)
                end
              end
            end
          else
            conn.send_message(event.room_id, "Invalid command")
          end
        end
      end
    end
  end
end
