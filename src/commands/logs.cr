@[Clip::Doc("Get logs.")]
struct Companion::Commands::Logs < Companion::Commands::Command
  include Clip::Mapper

  getter project : String
  getter service : String

  def run(conn : Caridina::Connection, manager : Manager, room_id : String)
    logs = manager.get_logs(@project, @service)
  rescue ex
    conn.send_message(room_id, ex.to_s)
  else
    conn.send_message(room_id, logs, "<pre><code>#{logs}</code></pre>")
  end
end
