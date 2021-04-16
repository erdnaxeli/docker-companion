@[Clip::Doc("Update a project.")]
struct Companion::Commands::Update < Companion::Commands::Command
  include Clip::Mapper

  getter project : String
  getter services : Array(String)

  def run(conn : Caridina::Connection, manager : Manager, room_id : String)
    @services.each do |service|
      msg_id = ""
      begin
        elapsed_time = Time.measure do
          msg_id = conn.send_message(room_id, "Removing the container...")
          manager.down_service(@project, service)
          conn.edit_message(room_id, msg_id, "Recreating the container...")
          manager.up_service(@project, service)
        end
        time = if elapsed_time < 2.seconds
                 "#{elapsed_time.milliseconds}ms"
               else
                 "#{elapsed_time.seconds}s"
               end

        conn.edit_message(
          room_id,
          msg_id,
          "Service #{service} of project #{@project} is up to date! (it tooks #{time})",
        )
      rescue ex
        puts ex.message
      end
    end
  end
end
