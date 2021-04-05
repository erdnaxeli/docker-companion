module Companion::Commands::Projects
  def self.run(conn : Caridina::Connection, manager : Manager, room_id : String,
               command : ProjectsCommand)
    msg = String.build do |str|
      str << "* " << manager.each_projects.join("\n* ")
    end

    conn.send_message(room_id, msg)
  end
end
