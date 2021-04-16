@[Clip::Doc("Shutdown a project's services.")]
struct Companion::Commands::Down < Companion::Commands::Command
  include Clip::Mapper

  getter project : String
  @[Clip::Argument]
  getter services : Array(String)? = nil

  def run(conn : Caridina::Connection, manager : Manager, room_id : String)
    if services = @services
      services.each do |service|
        manager.down_service(@project, service)
        conn.send_message(room_id, "Service #{service} of project #{@project} is down")
      end
    else
      manager.down(@project) do |service|
        conn.send_message(room_id, "Service #{service} down")
      end
    end
  end
end
