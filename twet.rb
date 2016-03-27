class Twet
  attr_accessor :owner, :name, :hatched_on, :level, :experience, :hungry, :color, :species, :trait, :personality, :fondness
  def initialize(owner)
    data = YAML.load_file('world.yaml') #TODO there must be a better way to decouple this
    @owner = owner
    @name = "#{owner}'s Twet"
    @color = data['color'].sample
    @hatched_on = Time.now
    @level = 1
    @experience = 0
    @hungry = true
    @species = data['species'].sample
    @trait = data['trait'].sample
    @personality = data['personality'].sample
    @fondness = 5
  end
end