# frozen_string_literal: true

require "discordrb"

DISCORD_SERVER_ID =  ENV["DISCORD_SERVER_ID"]
DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
MODERATORS_CHANNEL_ID =  ENV["MODERATORS_CHANNEL_ID"]

bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN, intents: [:server_messages], ignore_bots: true)

bot.register_application_command(:mods, "Send a message to the moderators", server_id: DISCORD_SERVER_ID) do |cmd|
  cmd.string("message", "A detailed report of the issue you're experiencing", required: true)
end

bot.application_command(:mods) do |event|
  message = event.options["message"]

  event.bot.send_message(MODERATORS_CHANNEL_ID, "Message from #{event.user.mention} in #{event.channel.mention}:\n\n#{message}")

  event.respond(content: "I've forwarded your message to the moderators and they'll respond as soon as possible!", ephemeral: true)
end

bot.run
