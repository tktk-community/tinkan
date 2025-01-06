module TinKan
  module EventHandlers
    # The event handler for deleting "_____ started a thread" messages when
    # they immediately follow the original message.
    class ThreadStarted
      def self.register(bot)
        bot.message do |event|
          next unless event.message.type == 18 # THREAD_CREATED

          # Discordrb unfortunately hides this information in an instance variable
          # and attempting to access the data its supposed to hydrate results in an
          # error due to our inability to get its caching mechanisms to work.
          referenced_message = event.message.instance_variable_get(:@message_reference)

          # Fetch the message directly before the thread started message.
          logs = Discordrb::API::Channel.messages(bot.token, event.channel.id, 1, event.message.id)
          previous_message_data = JSON.parse(logs).first

          if previous_message_data.dig("thread", "id") == referenced_message["channel_id"]
            event.message.delete
          end
        end
      end
    end
  end
end
