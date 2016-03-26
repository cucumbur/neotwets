require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'yaml'
require 'twitter'
require 'oauth'

require_relative 'tweet'
require_relative 'twet'
require_relative 'twegg'
require_relative 'user'

DEFAULT_CONFIG = 'config.yaml'
DEFAULT_DATABASE = 'database.yaml'
VERSION = '0.1.0'
SLEEP_TIME = 30

@config_file = DEFAULT_CONFIG
@database_file = DEFAULT_DATABASE

# Respond to console arguments
# -n <filename> creates a new server. be careful!
# -c <filename> starts server from chosen config file
# -d debug mode
def handle_arguments
  shell_options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: bot.rb [options]'

    opts.on('-d', '--debug', 'Runs in debug mode (reroutes tweets to console') do
      @debug_mode = true
      puts 'Running in debug mode.'
    end

    # opts.on('-n', 'Create a new server (overwrites any existing setup)') do |filename|
    #   #shell_options[:config] = filename
    #   print 'Are you sure you want to create a new server? y/n '
    #   abort('New server not created.') unless gets.chomp == 'n'
    #   @config_file = filename
    #   new_server
    # end

    opts.on('-c', '--config filename', 'Start from a non-default config') do |filename|
      #shell_options[:config] = filename
      @config_file = filename
    end
  end.parse!
end

# Loads a configuration file and sets up a new server from scratch
def new_server
  load_config
  @last_seen_tweet = 1 # set to twitters latest tweet?
end

def load_config
  puts 'Loading and applying config file.'
  abort("Config file doesn't exist.") unless File.exist?(@config_file)
  @config = YAML.load_file(@config_file)

  puts 'NeoTwets did not exit cleanly on last run.' unless @config['clean_exit']
  @config['clean_exit'] = false
  save_config
  # Create twitter config
  @twitter_client = Twitter::REST::Client.new do |conf|
    conf.consumer_key     = @config['twitter_consumer_key']
    conf.consumer_secret  = @config['twitter_consumer_secret']
    #conf.bearer_token     = @config['twitter_bearer_token'] if @config.key?('twitter_bearer_token')
    conf.access_token     = @config['twitter_access_token'] if @config.key?('twitter_access_token')
    conf.access_token_secret = @config['twitter_access_token_secret'] if @config.key?('twitter_access_token_secret')
  end
  puts "Logged into twitter as #{@twitter_client.user.screen_name}."

  @last_seen_tweet = @config['last_seen_tweet'] || 1

end

def save_config
  File.open(@config_file, 'w') do |file|
    file.write(YAML.dump(@config))
  end
end

def load_database
  puts 'Loading database.'
  abort("Database file doesn't exist.") unless File.exist?(@database_file)
  database = YAML.load_file(@database_file)
  @users = database[:user] || {}
  @twets = database[:twet] || {}
  @tweggs = database[:twegg] || {}
  puts "Databased loaded. #{@users.length} users, #{@twets.length} twets, and #{@tweggs.length} tweggs."
  if database[:last_saved]
    puts "Last save was on #{database[:last_saved].localtime}"
  else
    puts 'NeoTwets is working with a new database.'
  end
end

def save_database
  puts 'Saving database.'
  File.open(@database_file, 'w') do |file|
    database = {user: @users, twet: @twets, twegg: @tweggs, last_saved:Time.now}
    file.write(YAML.dump(database))
  end
  puts "Databased saved. #{@users.length} users, #{@twets.length} twets, and #{@tweggs.length} tweggs."
end

def rollover?
   Time.new.yday != @last_update.yday
end

# Updates any daily features such as hungriness
def daily_rollover
  puts 'Enacting daily rollover.'
  # Make all Twets hungry
  @twets.each do |twet|
    twet.hungry = true
  end
end

def respond_new_replies
  puts "Checking for new replies since tweet #{@last_seen_tweet}."
  @twitter_client.mentions({since_id: @last_seen_tweet, count: 20}).each do |tweet|
    user = tweet.user.screen_name
    puts "New reply found from @#{user}"
    if tweet.in_reply_to_user_id == @twitter_client.user.id
      tokens = tweet.full_text.split(" ")
      command = tokens[1].downcase
      case command
      when 'status' # gives user information about current state of twet
        puts "#{user} requested their status."
        @twitter_client.update("@#{user} Not right now")
      when 'egg'    # lets a new user get an egg to incubate
        puts "#{user} has received an egg."
        twegg = Twegg.new(user)
        @tweggs[user] = twegg
        tweet("@#{user} You have received a #{twegg.adjective} egg with #{twegg.color} #{twegg.pattern}!", tweet)
      else
        puts "The following tweet from #{user} was not understood: #{tweet.text}"
      end
      #@twitter_client.update("I got tweeted at by @#{tweet.user.screen_name}!")
      @last_seen_tweet = tweet.id if tweet.id > @last_seen_tweet
    end

  end
end

def cleanup
  puts 'Cleaning up.'
  @config['last_seen_tweet'] = @last_seen_tweet
  save_database
  @config['clean_exit'] = true
  save_config
end

def new_twet_id
  (@new_twet_id+=1) - 1
end

def main
  @shutdown = false
  puts 'Starting main loop.'
  until @shutdown do
    puts "There are #{@users.length} users, #{@twets.length} twets, and #{@tweggs.length} tweggs."
    respond_new_replies
    puts "Going to sleep for #{SLEEP_TIME} seconds."
    sleep SLEEP_TIME

  end

  cleanup
end

# Signal handlers for command-line interface
Signal.trap("INT") {
  puts 'NeoTwets has been sent an interrupt signal, preparing shutdown.'
  @shutdown = true
}
Signal.trap("TERM") {
  puts 'NeoTwets has been sent a terminate signal, preparing shutdown.'
  @shutdown = true
}

handle_arguments
load_config
load_database
main
puts 'Exiting.'
