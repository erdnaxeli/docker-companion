module Companion::Commands::Networks
  def self.run(conn : Caridina::Connection, manager : Manager, room_id : String,
               command : NetworksCommand)
    msg = String.build do |str|
      str << "* " << manager.networks.map do |n|
        %(#{n.name} #{n.id})
      end.join("\n* ")
    end

    conn.send_message(room_id, msg)
  end
end
