module Companion::Commands::Logs
  def self.run(conn : Caridina::Connection, manager : Manager, room_id : String,
               command : LogsCommand)
    logs = manager.get_logs(command.project, command.service)
  rescue ex
    conn.send_message(room_id, ex.to_s)
  else
    conn.send_message(room_id, logs, "<pre><code>#{logs}</code></pre>")
  end
end
