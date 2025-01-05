require_relative "base"

module TinKan
  module Commands
    # /mods <message>
    #
    # Allows users to send a message to the moderators for review.
    class Mods < Base
      COMMAND = :mods
      DESCRIPTION = "Send a message to the moderators"
      ARGUMENTS = [
        {name: "message", description: "A detailed report of the issue you're experiencing", type: :string, options: {required: true}}
      ].freeze

      MODERATORS_CHANNEL_ID = ENV["MODERATORS_CHANNEL_ID"].to_i
      MODERATOR_ROLE_ID = ENV["MODERATOR_ROLE_ID"].to_i

      def self.handle(event)
        new(event).handle
      end

      def initialize(event)
        @event = event
      end

      def handle
        message = event.options["message"]

        event.bot.send_message(MODERATORS_CHANNEL_ID, "<@&#{MODERATOR_ROLE_ID}> Message from #{event.user.mention} in #{event.channel.mention}:\n\n> #{message}")

        event.respond(content: "I've forwarded your message to the moderators and they'll respond as soon as possible!", ephemeral: true)
      end

      private

      attr_reader :event
    end
  end
end
