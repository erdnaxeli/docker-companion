require "./docker/client"

require "caridina"

require "option_parser"

module Companion
  VERSION = "0.1.0"

  def self.run : Nil
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

    c = Docker::Client.new(Docker::Client::Config.new)
    puts c.containers(true)

    c.pull_image("bash") do |r|
      puts r
    end

    puts "Creating bash container"
    o = Docker::CreateContainerOptions.new
    o.image = "bash"
    mount = Docker::CreateContainerOptions::HostConfig::Mount.new
    mount.target = "/tmp/home"
    mount.source = "/home"
    o.host_config.mounts << mount
    o.cmd << "sleep" << "20"
    r = c.create_container(o)
    puts r.id, r.warnings, r.message
    puts c.containers

    if id = r.id
      c.start_container(id)
    end
  end
end

Companion.run
