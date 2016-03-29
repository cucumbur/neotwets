def respond_new_replies
  puts "Checking for new replies since tweet #{@last_seen_tweet}."
  begin
    mentions = @twitter_client.mentions({since_id: @last_seen_tweet, count: 20})
  rescue Twitter::Error::TooManyRequests => error
    puts 'Rate limit exceeded, sleeping for some time...'
    sleep error.rate_limit.reset_in + 1
    retry
  end
  if mentions.size == 0
    puts 'No new replies.'
    return
  end
  puts "#{mentions.size} new replies."

  mentions.each do |tweet|
    user = tweet.user.screen_name
    puts "New reply found from @#{user}"

    if tweet.in_reply_to_user_id == @twitter_id
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
            @tweggs[user].incubated_on = Time.now
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
          puts 'In feed block'
          if @twets[user].hungry
            puts "#{user} fed their twet."
            @twets[user].hungry = false
            @twets[user].fondness += 1 unless @twets[user].fondness == MAX_FONDNESS
          elsif
          puts "#{user} tried to feed their twet but failed for some reason."
          end
        when 'status' # gives user information about current state of twet
          if twegg = @tweggs[user]
            tweet "@#{user} You have an unhatched #{twegg.adjective} twegg with #{twegg.color} #{twegg.pattern}. incubate?", tweet
          elsif @twets[user]
            twet = @twets[user]
            if twet.hungry then hungry_stmt = 'is hungry'  else hungry_stmt = "isn't hungry" end
            tweet "@#{user} #{twet.name} is a level #{twet.level} #{twet.species} with #{twet.experience} exp and #{hungry_stmt}.", tweet
          else
            puts "#{user} tried to get their status but they don't have a twet."
          end
        when 'relationship' #gives user information about the relationship between them and their twet
          if twet = @twets[user]
            puts  "#{user} is looking at their relationship with their twet."
            case
              when twet.fondness == 0
                tweet "@#{user} Wow... #{twet.name} hates your guts!", tweet
              when twet.fondness < 5
                tweet "@#{user} #{twet.name } doesn't like you very much.", tweet
              when twet.fondness == 5
                tweet "@#{user} #{twet.name } think you're okay.", tweet
              when twet.fondness < 10
                tweet "@#{user} #{twet.name } really likes you!", tweet
              when twet.fondness >= 10
                tweet "@#{user} #{twet.name } considers you their best friend!", tweet
            end
          else
            puts "#{user} tried to check their relationship but they don't have a twet."
          end
        when 'wallet'
          if twuser = @users[user]
            tweet "@#{user} You have #{twuser.neocoin} neocoins.", tweet
          else
            puts "#{user} tried to check their wallet but they aren't a user."
          end
        # gambling features
        when 'dice' # @neotwetsdev dice bet (neocoins) on (1-6)
          if (twuser = @users[user]) && tokens.size >= 4
            puts "#{user} is rolling the dice."
            bet = [tokens[3].to_i.abs, twuser.neocoin].min
            twuser.neocoin -= bet
            tokens[5].to_i.between?(1,6) ? guess = tokens[5].to_i : guess = rand(6)+1
            roll = rand(6)+1
            if roll == guess
              twuser.neocoin += (bet * 6)
              tweet "@#{user} You bet on #{guess} and the die landed on #{roll}. You win #{(bet * 5)} neocoin! Now you have #{twuser.neocoin}.", tweet
            else
              tweet "@#{user} You bet on #{guess} but the die landed on #{roll}. You lost #{(bet)} neocoin... Now you have #{twuser.neocoin}.", tweet
            end
          else
            puts "#{user} tried to roll the dice but isn't an actual user."
          end
        when 'coinflip' # @neotwetsdev coinflip bet (neocoins) on (heads,tails)
          if (twuser = @users[user]) && tokens.size >= 4
            puts "#{user} is flipping a coin."
            bet = [tokens[3].to_i.abs, twuser.neocoin].min
            twuser.neocoin -= bet
            ['heads, tails'].include? tokens[5].downcase ? guess = tokens[5].downcase : guess = ['heads', 'tails'].sample
            coin = ['heads', 'tails'].sample
            if guess == coin
              twuser.neocoin += (bet * 2)
              tweet "@#{user} You bet on #{guess} and the coin landed on #{coin}. You win #{(bet)} neocoin!", tweet
            else
              tweet "@#{user} You bet on #{guess} but the coin landed on #{coin}... You lose #{(bet)} neocoin.", tweet
            end
          else
            puts "#{user} tried to flip a coin but isn't an actual user."
          end
        when 'allowance'
          if twuser = @users[user]
            if !(twuser.got_allowance)
              puts "#{user} is collecting their allowance."
              given = ALLOWANCE_AMOUNT + rand(-10..10)
              twuser.neocoin += given
              twuser.got_allowance = true
              tweet "@#{user} You collected #{given} neocoin as allowance!", tweet
            else
              puts "#{user} tried to collect allowance but already got it today."
            end
          else
            puts "#{user} tried to collect allowance but aren't a real user."
          end
        when 'donate' # donate <# coin> to @<username>
          if (twuser = @users[user]) && tokens.size >= 5
            tokens[4].start_with?('@') ? recipient = tokens[4][1..-1] : recipient = tokens[4]
            if (twrecipient = @users[recipient])
              puts "#{user} is donating to  #{recipient}."
              donation = [tokens[2].to_i.abs, twuser.neocoin].min
              twuser.neocoin -= donation
              twrecipient.neocoin += donation
              tweet "@#{recipient} You have a generous friend! @#{user} donated #{donation} neocoin to you.", tweet
              # 1 in 100 donations, the donation fairy will bless the person who donated
              if rand(100) == 50
                puts 'The generation fairy has appeared!'
                blessing = rand(500..2000)
                twuser.neocoin += blessing
                tweet "@#{user} The donation fairy has blessed you with #{blessing} neocoin for your generosity. Nice!", tweet
              end
            else
              puts "#{user} tried to donate to #{recipient} but they don't exist."
            end

          end
        else
          puts "The following tweet from #{user} was not understood: #{tweet.text}"
      end
      @last_seen_tweet = tweet.id if tweet.id > @last_seen_tweet
    end

    save_database :silent

  end
end