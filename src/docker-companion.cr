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
    # url = ""
    # access_token = ""

    # parser = OptionParser.parse do |p|
    #   p.banner = "--url URL --access-token ACCESS_TOKEN"
    #   p.on("--url URL", "the homeserver url") { |u| url = u }
    #   p.on("--access-token ACCESS_TOKEN", "the bot account's access token") { |at| access_token = at }
    #   p.on("-h", "--help", "show this help") do
    #     puts p
    #     exit
    #   end
    # end

    # puts "url #{url} access_token #{access_token}"
    # if url == "" || access_token == ""
    #   puts parser
    # else
    #   conn = Caridina::ConnectionImpl.new(url, access_token)
    #   conn.send_message("!IZjjATKJFYVLSVzyMP:cervoi.se", "Hello, world!")
    # end

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

    # c.pull_image("bash") do |r|
    #   puts r
    # end

    # puts "Creating bash container"
    # o = Docker::CreateContainerOptions.new
    # o.image = "bash"
    # mount = Docker::CreateContainerOptions::HostConfig::Mount.new
    # mount.target = "/tmp/home"
    # mount.source = "/home"
    # o.host_config.mounts << mount
    # o.cmd << "sleep" << "20"
    # r = c.create_container(o)
    # puts r.id, r.warnings, r.message
    # puts c.containers

    # if id = r.id
    #   c.start_container(id)
    # end
  end
end

Companion.run
