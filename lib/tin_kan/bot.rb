require "discordrb"
require_relative "commands/mods"
require_relative "commands/list_private"
require_relative "event_handlers/join_private"
require_relative "event_handlers/invite_to_private"

module TinKan
  class Bot < Discordrb::Bot
    DISCORD_TOKEN = ENV["DISCORD_BOT_TOKEN"]
    DISCORD_SERVER_ID = ENV["DISCORD_SERVER_ID"].to_i
    BOT_USER_ID = ENV["DISCORD_BOT_USER_ID"].to_i

    ARCHIVE_CATEGORY_ID = ENV["ARCHIVE_CATEGORY_ID"].to_i
    META_CHANNEL_ID = ENV["META_CHANNEL_ID"].to_i
    META_CATEGORY_ID = ENV["META_CATEGORY_ID"].to_i
    MODERATORS_CATEGORY_ID = ENV["MODERATORS_CATEGORY_ID"].to_i

    UNARCHIVEABLE_CATEGORY_IDS = [
      ARCHIVE_CATEGORY_ID,
      META_CATEGORY_ID,
      MODERATORS_CATEGORY_ID,
      Commands::ListPrivate::CATEGORY_ID
    ]

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

    def archive_inactive_channels!
      thirty_days_ago = Time.now - 30 * 24 * 60 * 60
      sixty_days_ago = Time.now - 60 * 24 * 60 * 60

      server_response = JSON.parse(Discordrb::API::Server.resolve(token, DISCORD_SERVER_ID))
      server = Discordrb::Server.new(server_response, self)

      archive_category_response = JSON.parse(Discordrb::API::Channel.resolve(token, ARCHIVE_CATEGORY_ID))
      archive_category = Discordrb::Channel.new(archive_category_response, self, server)

      archiveable_channels_in(server).each do |channel|
        # Fetch the last few messages in the channel to account for the fact that the
        # most recent message might be the 30-day warning from the bot.
        messages = channel.history(5)
        last_user_message = messages.find { |message| message.author.id != BOT_USER_ID }
        warning_already_sent = messages.first&.author&.id == BOT_USER_ID

        channel_last_active_at = last_user_message&.timestamp || channel.creation_time

        if channel_last_active_at < sixty_days_ago
          send_message(channel.id, "This channel has now been quiet for more than 60 days. To keep things tidy, I'll be marking it as read-only and moving it to the `Archive` category. If you'd like us to bring it back, please let us know in <##{META_CHANNEL_ID}>!")

          channel.category = archive_category
          channel.sync_overwrites
        elsif channel_last_active_at < thirty_days_ago && !warning_already_sent
          send_message(channel.id, "Hello! This channel has been quiet for 30 days. We automatically archive channels that are inactive for **60 days**, since tidying up our channels makes it easier for people to find their way around. No content is lost when archiving channels, and we can always bring them back if they're needed again. If you'd like to keep this channel active, please start an on-topic conversation and we'll reset the timer. Thanks!")
        end

        sleep(1) # Simple rate limit handling
      end
    end

    private

    def archiveable_channels_in(server)
      return @archiveable_channels if defined?(@archiveable_channels)

      channels_response = Discordrb::API::Server.channels(token, DISCORD_SERVER_ID)

      @archiveable_channels = JSON.parse(channels_response)
        .map { |channel| Discordrb::Channel.new(channel, self, server) }
        .select { |channel| channel.type == 0 }
        .reject { |channel| UNARCHIVEABLE_CATEGORY_IDS.include?(channel.parent_id) }
    end
  end
end
