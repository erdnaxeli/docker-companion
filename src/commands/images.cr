module Companion::Commands::Images
  def self.run(conn : Caridina::Connection, manager : Manager, room_id : String,
               command : ImagesCommand)
    msg = String.build do |str|
      str << "* " << manager.images.map do |t, i|
        %(#{t} #{i.ids_history[0]?})
      end.join("\n* ")
    end

    conn.send_message(room_id, msg)
  end
end
