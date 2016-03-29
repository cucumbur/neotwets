class User
  attr_accessor :name, :twet, :neocoin, :got_allowance
  attr_reader :playing_since
  def initialize(name, twet_id)
    @name = name
    @twet = twet_id
    @neocoin = 100
    @playing_since = Time.now
    @got_allowance = false
  end
end