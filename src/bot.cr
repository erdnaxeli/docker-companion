class Companion::Bot
  Log = Companion::Log.for(self)

  @first_sync = true

  def initialize(@users : Array(String), @conn : Caridina::Connection, @manager : Manager)
  end

  def exec(sync : Caridina::Events::Sync)
    follow_invites(sync)

    if @first_sync
      # Skip the first sync messages as it can contains messages already read.
      @first_sync = false
      return
    end

    sync.room_events do |event|
      if (message = event.message?) && event.sender != @conn.user_id && @users.includes? event.sender
        if parameters = Parameters.parse(message.body)
          exec_cmd(parameters, event)
        else
          @conn.send_message(event.room_id, "Invalid command")
        end
      end
    end
  end

  private def exec_cmd(parameters, event)
    OptionParser.parse(parameters) do |parser|
      parser.banner = "COMMAND [OPTIONS]"
      parser.on("down", "shutdown a project's services") do
        parser.banner = "down PROJECT [SERVICES]"
        parser.unknown_args do |args|
          if args.size > 0
            project = args.shift
            services = args

            if services.empty?
              @conn.send_message(event.room_id, "You need to provide at least one service to shutdown")
              next
            end

            services.each do |service|
              @manager.down_service(project, service)
              @conn.send_message(event.room_id, "Service #{service} of project #{project} is down")
            end
          else
            @conn.send_message(event.room_id, "You need to provide a project")
          end
        end
      end
      parser.on("projects", "list projects") do
        msg = String.build do |str|
          str << "* " << @manager.each_projects.join("\n* ")
        end

        @conn.send_message(event.room_id, msg)
      end
      parser.on("images", "list images") do
        msg = String.build do |str|
          str << "* " << @manager.images.map { |t, i| %(#{t} #{i.ids_history[0]?}) }.join("\n* ")
        end

        @conn.send_message(event.room_id, msg)
      end
      parser.on("networks", "list networks") do
        msg = String.build do |str|
          str << "* " << @manager.networks.map { |n| %(#{n.name} #{n.id}) }.join("\n* ")
        end

        @conn.send_message(event.room_id, msg)
      end
      parser.on("update", "update a project") do
        parser.banner = "update PROJECT [SERVICES]"

        parser.unknown_args do |args|
          if args.size > 0
            project = args.shift
            services = args

            if services.empty?
              @conn.send_message(event.room_id, "You need to provide at least one service to update")
              next
            end

            services.each do |service|
              msg_id = ""
              begin
                elapsed_time = Time.measure do
                  msg_id = @conn.send_message(event.room_id, "Removing the container...")
                  @manager.down_service(project, service)
                  @conn.edit_message(event.room_id, msg_id, "Recreating the container...")
                  @manager.up_service(project, service)
                end
                time = if elapsed_time < 2.seconds
                         "#{elapsed_time.milliseconds}ms"
                       else
                         "#{elapsed_time.seconds}s"
                       end

                @conn.edit_message(
                  event.room_id,
                  msg_id,
                  "Service #{service} of project #{project} is up to date! (it tooks #{time})",
                )
              rescue ex
                puts ex.message
              end
            end
          else
            @conn.send_message(event.room_id, "You need to provide a project")
          end
        end
      end
      parser.on("-h", "--help", "show this help") do
        @conn.send_message(event.room_id, parser.to_s)
      end
      parser.invalid_option { }
      parser.unknown_args do |args|
        if args.size > 0 && args[0] == "help"
          @conn.send_message(event.room_id, parser.to_s)
        end
      end
    end
  end

  private def follow_invites(sync)
    sync.invites do |event|
      Log.info &.emit("Join room", room_id: event.room_id)
      @conn.join(event.room_id)
      @conn.send_message(
        event.room_id,
        "Hi! I am your new companion, here to help you manage your docker services. Try the 'help' command to begin."
      )
    end
  end
end
