class User
  attr_accessor :name, :twet, :neocoin
  def initialize(name, twet_id)
    @name = name
    @twet = twet_id
    @neocoin = 100
  end
end