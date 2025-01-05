require "discordrb"
require_relative "commands/mods"
require_relative "commands/list_private"
require_relative "event_handlers/join_private"
require_relative "event_handlers/invite_to_private"

module TinKan
  class Bot < Discordrb::Bot
    DISCORD_TOKEN = ENV["DISCORD_BOT_TOKEN"]
    DISCORD_SERVER_ID = ENV["DISCORD_SERVER_ID"].to_i

    def initialize
      super(token: DISCORD_TOKEN, intents: [:server_messages], ignore_bots: true)
    end

    def run
      Commands::Mods.register(self, server_id: DISCORD_SERVER_ID)
      Commands::ListPrivate.register(self, server_id: DISCORD_SERVER_ID)
      EventHandlers::JoinPrivate.register(self)
      EventHandlers::InviteToPrivate.register(self)

      Kernel.at_exit { stop }

      super
    end
  end
end
