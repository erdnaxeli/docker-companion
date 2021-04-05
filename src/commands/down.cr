module Companion::Commands::Down
  def self.run(conn : Caridina::Connection, manager : Manager, room_id : String,
               command : DownCommand)
    services = command.services
    if services.nil?
      manager.down(command.project) do |service|
        conn.send_message(room_id, "Service #{service} down")
      end
    else
      services.each do |service|
        manager.down_service(command.project, service)
        conn.send_message(room_id, "Service #{service} of project #{command.project} is down")
      end
    end
  end
end
