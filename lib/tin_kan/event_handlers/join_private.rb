module TinKan
  module EventHandlers
    # The button handler for requesting access to protected channels.
    class JoinPrivate
      def self.register(bot)
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
      end
    end
  end
end
