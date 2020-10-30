require "./docker/client"
require "./docker/compose"
require "./manager"

require "caridina"

require "file"
require "option_parser"
require "yaml"

module Companion
  VERSION = "0.1.0"

  struct Config
    include YAML::Serializable

    struct Matrix
      include YAML::Serializable

      property homeserver : String
      property access_token : String
    end

    property matrix : Matrix
    property users : Array(String)
  end

  def self.read_config(filename = "config.yaml") : Config
    content = File.read(filename)
    Config.from_yaml(content)
  end

  def self.run : Nil
    config = read_config

    conn = Caridina::ConnectionImpl.new(
      config.matrix.homeserver,
      config.matrix.access_token,
    )
    channel = Channel(Caridina::Events::Sync).new
    conn.sync(channel)

    loop do
      sync = channel.receive
      sync.room_events do |event|
        if (message = event.message?) && event.sender != conn.user_id && config.users.includes? event.sender
          conn.send_message(event.room_id, message.body)
        end
      end
    end

    c = Manager.new(Docker::Client::Local.new)
    c.add_project(
      "bash",
      %(
        version: "3.8"
        services:
          test:
            image: wardsco/sleep
      )
    )
    c.up("bash")
  end
end
