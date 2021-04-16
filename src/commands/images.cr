@[Clip::Doc("List images.")]
struct Companion::Commands::Images < Companion::Commands::Command
  include Clip::Mapper

  def run(conn : Caridina::Connection, manager : Manager, room_id : String)
    msg = String.build do |str|
      str << "* " << manager.images.map do |t, i|
        %(#{t} #{i.ids_history[0]?})
      end.join("\n* ")
    end

    conn.send_message(room_id, msg)
  end
end
