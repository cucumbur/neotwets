require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'yaml'
require 'twitter'
require 'firebase'
require 'oauth'

DEFAULT_CONFIG = 'config.yaml'
VERSION = '0.1.0'

@config_file = DEFAULT_CONFIG

# Respond to console arguments
# -n <filename> creates a new server. be careful!
# -c <filename> starts server from chosen config file
shell_options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: bot.rb [options]'

  opts.on('-n', 'Create a new server (overwrites any existing setup)') do |filename|
    #shell_options[:config] = filename
    print 'Are you sure you want to create a new server? y/n '
    abort('New server not created.') unless gets.chomp == 'n'
    @config_file = filename
    new_server
  end

  opts.on('-c', 'Start from a non-default config') do |filename|
    #shell_options[:config] = filename
    @config_file = filename
    load_config
  end
end.parse!


# Loads a configuration file and sets up a new server from scratch
def new_server (filename)
  load_config(filename)
end

def load_config
  abort("Config file doesn't exist.") unless File.exist?(filename)
  @config = YAML.load_file(filename)

  # Create twitter config
  @twitter_client = Twitter::REST::Client.new do |conf|

    conf.consumer_key     = @config['twitter_consumer_key']
    conf.consumer_secret  = @config['twitter_consumer_secret']
    conf.bearer_token     = @config['twitter_bearer_token'] if @config.key?('twitter_bearer_token')
    conf.access_token     = @config['twitter_access_token'] if @config.key?('twitter_access_token')
    conf.access_token_secret = @config['twitter_access_token_secret'] if @config.key?('twitter_access_token_secret')
  end
end

def save_config
  File.open(@config_file, 'w') do |file|
    file.write(YAML.dump(@config))
  end
end


def twitter_prepare
  @config['twitter_bearer_token'] = @twitter_client.bearer_token
  # Later, this will allow you to authorize if you don't have token in config
  #unless @twitter_client.credentials?
  #
  #end
  save_config
end