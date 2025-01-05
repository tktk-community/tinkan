module TinKan
  module EventHandlers
    # The button handler for adding users to protected channels.
    class InviteToPrivate
      def self.register(bot)
        bot.button(custom_id: /^invite_to_private:/) do |event|
          user_id = event.interaction.button.custom_id.split(":").last.to_i
          user_response = Discordrb::API::User.resolve(bot.token, user_id)
          user_data = JSON.parse(user_response)
          user = Discordrb::User.new(user_data, event.bot)

          event.channel.define_overwrite(user, 1024, 0)

          event.update_message(content: "Welcome to the channel, #{user.mention}!")
        end
      end
    end
  end
end
