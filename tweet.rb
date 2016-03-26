def tweet(text, in_reply_to = nil)
  if @debug_mode
    puts "(D) Tweeting '#{text}'."
  else
    @twitter_client.update(text, in_reply_to_status:in_reply_to)
  end
end