@[Clip::Doc("List projects.")]
struct Companion::Commands::Projects < Companion::Commands::Command
  include Clip::Mapper

  def run(conn : Caridina::Connection, manager : Manager, room_id : String)
    msg = String.build do |str|
      str << "* " << manager.each_projects.join("\n* ")
    end

    conn.send_message(room_id, msg)
  end
end
