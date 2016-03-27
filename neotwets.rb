require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'yaml'
require 'twitter'

require_relative 'tweet'
require_relative 'twet'
require_relative 'twegg'
require_relative 'user'

DEFAULT_CONFIG    = 'config.yaml'
DEFAULT_WORLD     = 'world.yaml'
DEFAULT_DATABASE  = 'database.yaml'
VERSION = '0.1.0'
SLEEP_TIME = 60         # the amount of time, in seconds, to wait in between running the main loop
CHECK_EVENT_TIME = 120  # the amount of time, in seconds, to wait in between checking for events to respond to

MAX_FONDNESS = 10


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
  @config['last_update'] = Time.now unless @config['last_update']
  puts 'NeoTwets did not exit cleanly on last run.' unless @config['clean_exit']
  @config['clean_exit'] = false
  save_config :silent
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

def save_config(silent = nil)
  puts 'Saving configuration file.' unless silent
  File.open(@config_file, 'w') do |file|
    file.write(YAML.dump(@config))
  end
end

def load_database
  puts 'Loading database.'
  abort("Database file doesn't exist.") unless File.exist?(@database_file)
  database = YAML.load_file(@database_file)
  database ||= {}
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
   Time.new.yday != @config['last_update'].yday
end

# Updates any daily features such as hungriness
def daily_rollover
  @config['last_update'] = Time.now
  puts 'Enacting daily rollover.'
  @twets.each do |owner, twet|
    # All pets that are hungry lose fondness
    puts 'Making all hungry twets lose fondness.'
    twet.fondness -= 1 if twet.hungry
    # Make all Twets hungry
    puts 'Making all twets hungry.'
    twet.hungry = true
  end
end

def check_events
  # go through all tweggs, sees if they are incubated, and hatches them if its been an hour
  time_to_hatch = 60 * 10
  time_to_warn  = 60 * 60 * 48
  time_to_delete= 60 * 60 * 12
  # Twegg check
  @tweggs.each do |user, twegg|
    if twegg.incubated && (twegg.incubated_on + time_to_hatch) < Time.now
      hatch_twegg(twegg)
    elsif (Time.now - twegg.created_on) > (time_to_warn + time_to_delete)
      puts 'This is where you delete a twegg.'
    elsif (Time.now - twegg.created_on) > time_to_warn
      puts 'This is where you would warn that you will delete a twegg soon'
    end
  end
  # Twet checks
  @twets.each do |owner, twet|
    # Fondness check
    tweet "@#{owner} #{twet.name} really likes you!" if twet.fondness == MAX_FONDNESS
  end
end

def hatch_twegg(twegg)
  owner = twegg.owner
  puts "#{owner}'s twegg is hatching!"
  twet = Twet.new(owner, @config['new_twet_id'])
  @config['new_twet_id'] += 1
  @twets[owner] = twet
  @tweggs.delete(owner)
  # Now that they have a twet, create a database entry for the user
  @users[owner] = User.new(owner, twet.id)
  tweet "@#{owner} Your twegg hatched! It is a #{twet.trait} #{twet.color} #{twet.species} with a #{twet.personality}."
end

def respond_new_replies
  puts "Checking for new replies since tweet #{@last_seen_tweet}."
  mentions = @twitter_client.mentions({since_id: @last_seen_tweet, count: 20})
  if mentions.size == 0
    puts 'No new replies.'
    return
  end
  puts "#{mentions.size} new replies."

  mentions.each do |tweet|
    user = tweet.user.screen_name
    puts "New reply found from @#{user}"
    if tweet.in_reply_to_user_id == @twitter_client.user.id
      tokens = tweet.full_text.split(" ")
      command = tokens[1].downcase
      case command
      when 'egg'    # lets a new user get an egg to incubate
        if @tweggs[user]
          puts 'User requested twegg, but they already had one.'
        else
          puts "#{user} has received an egg."
          twegg = Twegg.new(user)
          @tweggs[user] = twegg
          tweet "@#{user} You have received a #{twegg.adjective} egg with #{twegg.color} #{twegg.pattern}!", tweet
        end
      when 'incubate'
        if @tweggs[user]
          puts "#{user} has incubated their twegg."
          tweet "@#{user} You've put your twegg in the incubation chamber. It should hatch soon!", tweet
          @tweggs[user].incubated = true
        else
          puts 'User attempted to incubate but had no twegg.'
        end
      when 'reject'
        if @tweggs[user]
          puts "#{user} rejected their twegg."
          @tweggs.delete(user)
          world = YAML.load_file('world.yaml')
          rejection = world['twegg_rejection_phrases'].sample
          tweet "@#{user} You #{rejection} Try again in 2 hours.", tweet #TODO actually make there a minimum of two hours to try again
        else
          puts "#{user} tried to reject a twegg but did not have one."
        end
      when 'name'
        unless @twets[user]
          puts "#{user} tried to name a a twet but does not have one."
          return
        end
        if @twets[user].name == "#{user}'s Twet"    # let them rename it only if its the default name
          puts "#{user} named their twet #{tokens[2]}."
          @twets[user].name = tokens[2]
          tweet ".@#{user} is now the proud parent of #{@twets[user].name} the #{@twets[user].species}!"
        else
          puts "#{user} tried to name their twet but it was already named."
        end
      when 'feed'
        if @twets[user].hungry
          puts "#{user} fed their twet."
          @twets[user].hungry = false
          @twets[user].fondness += 1 unless @twets[user].fondness == MAX_FONDNESS
        elsif
          puts "#{user} tried to feed their twet but failed for some reason."
        end
      when 'status' # gives user information about current state of twet
        if @twets[user]
          twet = @twets[user]
          if twet.hungry then hungry_stmt = 'is hungry'  else hungry_stmt = "isn't hungry" end
          tweet "@#{user} #{twet.name} is a level #{twet.level} #{twet.species} with #{twet.experience} exp and #{hungry_stmt}."
        else
          puts "#{user} tried to get their status but they don't have a twet.."
        end
      else
        puts "The following tweet from #{user} was not understood: #{tweet.text}"
      end
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
  time_since_check_events = CHECK_EVENT_TIME
  @shutdown = false
  puts 'Starting main loop.'
  until @shutdown do
    puts "There are #{@users.length} users, #{@twets.length} twets, and #{@tweggs.length} tweggs."
    check_events and time_since_check_events = 0 if time_since_check_events >= CHECK_EVENT_TIME
    respond_new_replies
    daily_rollover if rollover?
    save_config :silent
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
