require "caridina/syncer"

require "./commands"

class Companion::Bot
  Log = Companion::Log.for(self)

  @first_sync = true

  def initialize(@users : Array(String), @conn : Caridina::Connection, @manager : Manager)
    @syncer = Caridina::Syncer.new
    @syncer.on(Caridina::Events::Message) do |event|
      event = event.as(Caridina::Events::Message)
      room_id = event.room_id.not_nil!
      @conn.send_receipt(room_id, event.event_id)

      if @first_sync
        # Skip the first sync messages as it can contains messages already read.
        next
      end

      if event.sender != @conn.user_id && @users.includes?(event.sender) && (message = event.content.as?(Caridina::Events::Message::Text))
        if parameters = Parameters.parse(message.body)
          # The typing notification act as a loading spinner.
          @conn.typing(room_id) do
            exec_cmd(parameters, event)
          end
        else
          @conn.send_message(room_id, "Invalid command")
        end
      end
    end
    @syncer.on(Caridina::Events::StrippedState, ->follow_invites(Caridina::Events::Event))
  end

  def exec(sync : Caridina::Responses::Sync)
    @syncer.process_response(sync)

    if @first_sync
      @first_sync = false
    end
  end

  private def exec_cmd(parameters, event)
    room_id = event.room_id.not_nil!

    begin
      command = Commands::Command.parse(parameters)
    rescue ex : Clip::Error
      @conn.send_message(room_id, ex.to_s)
      return
    end

    case command
    when Clip::Mapper::Help
      @conn.send_message(room_id, command.help(nil))
    else
      command.run(@conn, @manager, room_id)
    end
  end

  private def follow_invites(event)
    event = event.as(Caridina::Events::StrippedMember)
    room_id = event.room_id.not_nil!

    if content = event.content.as?(Caridina::Events::Member::Content)
      if content.membership == Caridina::Events::Member::Membership::Invite
        Log.info &.emit("Join room", room_id: room_id)
        @conn.join(room_id)
        @conn.send_message(
          room_id,
          "Hi! I am your new companion, here to help you manage your docker services. " \
          "Try the 'help' command to begin."
        )
      end
    end
  end
end
