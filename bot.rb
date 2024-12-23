# frozen_string_literal: true

require "discordrb"

DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
DISCORD_SERVER_ID = ENV["DISCORD_SERVER_ID"].to_i
MODERATORS_CHANNEL_ID = ENV["MODERATORS_CHANNEL_ID"].to_i
MODERATOR_ROLE_ID = ENV["MODERATOR_ROLE_ID"].to_i
PRIVATE_CATEGORY_ID = ENV["PRIVATE_CATEGORY_ID"].to_i

bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN, intents: [:server_messages], ignore_bots: true)

Kernel.at_exit { bot.stop }

# /mods <message>
#
# Allows users to send a message to the moderators for review.
bot.register_application_command(:mods, "Send a message to the moderators", server_id: DISCORD_SERVER_ID) do |cmd|
  cmd.string("message", "A detailed report of the issue you're experiencing", required: true)
end

bot.application_command(:mods) do |event|
  message = event.options["message"]

  event.bot.send_message(MODERATORS_CHANNEL_ID, "<@&#{MODERATOR_ROLE_ID}> Message from #{event.user.mention} in #{event.channel.mention}:\n\n#{message}")

  event.respond(content: "I've forwarded your message to the moderators and they'll respond as soon as possible!", ephemeral: true)
end

# /list-private [filter]
#
# Lists all private channels that the bot has access to, allowing users to request access to them.
bot.register_application_command(:"list-private", "List private/protected channels you can join", server_id: DISCORD_SERVER_ID) do |cmd|
  cmd.string("filter", "An optional filter to narrow the results", required: false)
end

bot.application_command(:"list-private") do |event|
  filter = event.options["filter"]&.downcase

  # NOTE: Although the `discordrb` gem is supposed to aggressively cache objects, I can't seem to
  # get it to work at all. So, unfortunately, we have to fetch the channels every time.
  channels_response = Discordrb::API.request(
    :guilds_sid_channels,
    event.server.id,
    :get,
    "#{Discordrb::API.api_base}/guilds/#{event.server.id}/channels",
    content_type: :json,
    Authorization: bot.token
  )

  channels = JSON.parse(channels_response)
    .map { |channel| Discordrb::Channel.new(channel, bot, event.server) }
    .select { |channel| channel.parent_id == PRIVATE_CATEGORY_ID }

  if filter && !filter.empty?
    channels = channels.select { |channel| channel.name.downcase.include?(filter) || channel.topic.downcase.include?(filter) }
  end

  channels = channels.select do |channel|
    channel.permission_overwrites.values.none? { |overwrite| overwrite.type == :member && overwrite.id == event.user.id }
  end

  if channels.empty?
    event.respond(content: "Sorry! I couldn't find any unjoined protected channels that match your criteria. Try again with a different filter.", ephemeral: true)
  else
    event.respond(content: "These channels are locked, protected channels to give marginalized folks a safe space. We don't police identities! If you request to join an identity channel that applies to you, we're not going to ask you to prove it — we just invite you.", ephemeral: true)

    channels.each do |channel|
      member_count = channel.permission_overwrites.values.count { |overwrite| overwrite.type == :member }

      event.send_message(content: "**##{channel.name} [#{member_count}]:** #{channel.topic}", ephemeral: true) do |_, view|
        view.row do |row|
          row.button(label: "Join", style: :primary, custom_id: "join_private:#{channel.id}", emoji: {name: "🔓"})
        end
      end
    end
  end
end

# The button handler for requesting access to protected channels.
bot.button(custom_id: /^join_private:/) do |event|
  channel_id = event.interaction.button.custom_id.split(":").last.to_i
  channel_response = Discordrb::API::Channel.resolve(bot.token, channel_id)
  channel_data = JSON.parse(channel_response)
  channel = Discordrb::Channel.new(channel_data, event.bot, event.server)

  request = "#{event.user.mention} would like to join this channel! Is this community okay with that?"

  components = Discordrb::Components::View.new do |view|
    view.row do |row|
      row.button(label: "Invite", style: :primary, custom_id: "invite_to_private:#{event.user.id}", emoji: {name: "✅"})
    end
  end

  event.bot.send_message(channel.id, request, false, nil, nil, nil, nil, components)

  # Update the original message to let the user know their request was sent and
  # remove the button to prevent duplicate requests.
  event.update_message(content: "Your request to join #{channel.mention} has been sent! Please give the community some time to respond.", ephemeral: true)
end

# The button handler for adding users to protected channels.
bot.button(custom_id: /^invite_to_private:/) do |event|
  user_id = event.interaction.button.custom_id.split(":").last.to_i
  user_response = Discordrb::API::User.resolve(bot.token, user_id)
  user_data = JSON.parse(user_response)
  user = Discordrb::User.new(user_data, event.bot)

  event.channel.define_overwrite(user, 1024, 0)

  event.update_message(content: "Welcome to the channel, #{user.mention}!")
end

bot.run
