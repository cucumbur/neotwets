class User
  attr_accessor :name, :twet, :neocoin, :gotten_allowance
  attr_reader :playing_since
  def initialize(name, twet_id)
    @name = name
    @twet = twet_id
    @neocoin = 100
    @playing_since = Time.now
    @gotten_allowance = false
  end
end