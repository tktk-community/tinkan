require_relative "base"

module TinKan
  module Commands
    # /list-private [filter]
    #
    # Lists all private channels that the bot has access to, allowing users to request access to them.
    class ListPrivate < Base
      COMMAND = :"list-private"
      DESCRIPTION = "List private/protected channels you can join"
      ARGUMENTS = [
        {name: "filter", description: "An optional filter to narrow the results", type: :string, options: {required: false}}
      ].freeze

      CATEGORY_ID = ENV["PRIVATE_CATEGORY_ID"].to_i

      def handle
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

      private

      def filter
        @filter ||= event.options["filter"]&.downcase
      end

      # NOTE: Although the `discordrb` gem is supposed to aggressively cache objects, I can't seem to
      # get it to work at all. So, unfortunately, we have to fetch the channels every time the command is run.
      def channels
        return @channels if defined?(@channels)

        channels_response = Discordrb::API.request(
          :guilds_sid_channels,
          event.server.id,
          :get,
          "#{Discordrb::API.api_base}/guilds/#{event.server.id}/channels",
          content_type: :json,
          Authorization: event.bot.token
        )

        @channels = JSON.parse(channels_response)
          .map { |channel| Discordrb::Channel.new(channel, event.bot, event.server) }
          .select { |channel| channel.parent_id == CATEGORY_ID }

        if filter && !filter.empty?
          @channels = @channels.select { |channel| channel.name.downcase.include?(filter) || channel.topic.downcase.include?(filter) }
        end

        @channels = @channels.select do |channel|
          channel.permission_overwrites.values.none? { |overwrite| overwrite.type == :member && overwrite.id == event.user.id }
        end

        @channels
      end
    end
  end
end
