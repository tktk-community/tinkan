module TinKan
  module Commands
    class NotImplementedError < StandardError; end

    class Base
      def self.register(bot, server_id:)
        bot.register_application_command(self::COMMAND, self::DESCRIPTION, server_id: server_id) do |cmd|
          self::ARGUMENTS.each do |arg|
            cmd.send(arg[:type], arg[:name], arg[:description], **arg[:options])
          end
        end

        bot.application_command(self::COMMAND, &method(:handle))
      end

      def self.handle(event)
        new(event).handle
      end

      def initialize(event)
        @event = event
      end

      def handle
        raise NotImplementedError, "You must implement the `handle` method in your command class."
      end

      private

      attr_reader :event
    end
  end
end
