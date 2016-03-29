require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'yaml'
require 'twitter'

require_relative 'respond'
require_relative 'tweet'

require_relative 'twet'
require_relative 'twegg'
require_relative 'user'



DEFAULT_CONFIG    = 'config.yaml'
DEFAULT_WORLD     = 'world.yaml'
DEFAULT_DATABASE  = 'database.yaml'
VERSION = '0.1.2'
DEFAULT_SLEEP_TIME = 20         # the amount of time, in seconds, to wait in between running the main loop
DEFAULT_CHECK_TWEETS_TIME = 120
DEFAULT_CHECK_EVENTS_TIME = 240  # the amount of time, in seconds, to wait in between checking for events to respond to

MAX_FONDNESS = 10
ALLOWANCE_AMOUNT = 50

@sleep_time = DEFAULT_SLEEP_TIME
@check_tweets_time = DEFAULT_CHECK_TWEETS_TIME
@check_events_time = DEFAULT_CHECK_EVENTS_TIME
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

    opts.on('--tweetinterval interval', Integer, 'Check tweets after this many seconds') do |interval|
      @check_tweets_time = interval
    end

    opts.on('--eventinterval interval', Integer, 'Check events after this many seconds') do |interval|
      @check_events_time = interval
    end

    # opts.on('-n', 'Create a new server (overwrites any existing setup)') do |filename|
    #   #shell_options[:config] = filename
    #   print 'Are you sure you want to create a new server? y/n '
    #   abort('New server not created.') unless gets.chomp == 'n'
    #   @config_file = filename
    #   new_server
    # end

    opts.on('-cfilename', '--config filename', 'Start from a non-default config') do |filename|
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
  begin
    @twitter_name = @twitter_client.user.screen_name
    @twitter_id = @twitter_client.user.id
  rescue Twitter::Error::TooManyRequests => error
    puts 'Rate limit exceeded, sleeping for some time...'
    sleep error.rate_limit.reset_in + 1
    retry
  end
  puts "Logged into twitter as #{@twitter_name}."

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

def save_database(silent = nil)
  puts 'Saving database.' unless silent
  File.open(@database_file, 'w') do |file|
    database = {user: @users, twet: @twets, twegg: @tweggs, last_saved:Time.now}
    file.write(YAML.dump(database))
  end
  puts "Databased saved. #{@users.length} users, #{@twets.length} twets, and #{@tweggs.length} tweggs." unless silent
end

def rollover?
   Time.new.yday != @config['last_update'].yday
end

# Updates any daily features such as hungriness
def daily_rollover
  # The "fortune" is like a randomly selected message of the day to let people know when rollover occurs
  fortune = YAML.load_file('world.yaml')['fortune'].sample
  tweet "A new day dawns in NeoTwetopia. #{fortune}"
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
  @users.each do |name, twuser|
    # Reset allowance
    twuser.got_allowance = false
  end
end

def check_events
  puts 'Checking events.'
  # go through all tweggs, sees if they are incubated, and hatches them if its been an hour
  time_to_hatch = 60 * 30
  time_to_warn  = 60 * 60 * 24
  time_to_delete= 60 * 60 * 36
  # Twegg check
  @tweggs.each do |user, twegg|
    if twegg.incubated && (twegg.incubated_on + time_to_hatch) < Time.now
      hatch_twegg(twegg)

    elsif (Time.now - twegg.created_on) > (time_to_warn + time_to_delete)
      #@tweggs.remove(user)
      puts "#{user} had their twegg deleted."
    elsif (Time.now - twegg.created_on) > time_to_warn
      puts "#{user} has been warned that their twegg will be removed soon."
      tweet "@#{user} If you don't incubate your egg, it will be gone in #{(time_to_delete / (60 * 60)).to_i} hours."
    end
  end
  # Twet checks
  @twets.each do |owner, twet|
    # Fondness check
    #tweet "@#{owner} #{twet.name} really likes you!" if twet.fondness == MAX_FONDNESS #TODO Don't enable this until a feature is implemented so it won't repeatedly badger the user
    # Level up
    if twet.level_up?
      puts "#{owner}'s twet #{twet.name} is leveling up to lvl #{twet.level.next}"
      twet.level_up
      tweet "@#{owner} #{twet.name} has grown to level #{twet.level}!"
    end

  end

  # User checks
  # @twets.each do |name, user|
  #
  # end
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
  first_run = true
  checked_tweets_time = Time.now
  checked_events_time = Time.now
  @shutdown = false
  puts 'Starting main loop.'
  until @shutdown do
    if first_run || ((Time.now - checked_tweets_time) >= @check_tweets_time)
      puts "There are #{@users.length} users, #{@twets.length} twets, and #{@tweggs.length} tweggs."
      respond_new_replies
      checked_tweets_time = Time.now
    end

    if first_run || ((Time.now - checked_events_time) >= @check_events_time)
      check_events
      checked_events_time = Time.now
    end
    first_run = false
    daily_rollover if rollover?
    save_config :silent
    save_database :silent
    #puts "Going to sleep for #{SLEEP_TIME} seconds."
    sleep @sleep_time
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
