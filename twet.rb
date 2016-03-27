class Twet
  attr_accessor :owner, :name, :hatched_on, :level, :experience, :hungry, :species, :trait, :personality
  def initialize(name, owner)
    data = YAML.load_file('world.yaml') #TODO there must be a better way to decouple this
    @name = name
    @owner = owner
    @color = data['color'].sample
    @pattern = data['pattern'].sample
    @hatched_on = Time.now
    @level = 1
    @experience = 0
    @hungry = true
    @species = data['species'].sample
    @trait = data['trait'].sample
    @personality = data['personality'].sample
  end
end