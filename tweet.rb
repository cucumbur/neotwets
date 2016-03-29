def tweet(text, in_reply_to = nil)
  if @debug_mode
    puts "(D) Tweeting '#{text}'."
  else
    begin
      @twitter_client.update(text, in_reply_to_status:in_reply_to)
    rescue Twitter::Error::TooManyRequests => error
      puts 'Rate limit exceeded, sleeping for some time...'
      sleep error.rate_limit.reset_in + 1
      retry
    end
  end
end