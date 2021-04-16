@[Clip::Doc("List networks.")]
struct Companion::Commands::Networks < Companion::Commands::Command
  include Clip::Mapper

  def run(conn : Caridina::Connection, manager : Manager, room_id : String)
    msg = String.build do |str|
      str << "* " << manager.networks.map do |n|
        %(#{n.name} #{n.id})
      end.join("\n* ")
    end

    conn.send_message(room_id, msg)
  end
end
