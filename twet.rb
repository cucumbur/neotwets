class Twet
  attr_accessor :owner, :id, :name, :hatched_on, :level, :experience, :hungry, :color, :species, :trait, :personality, :fondness
  def initialize(owner, id)
    data = YAML.load_file('world.yaml') #TODO there must be a better way to decouple this
    @owner = owner
    @id = id
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

  def level_up?; (@experience) >= exp_to_next_level end

  def level_up
    @experience -= exp_to_next_level
    @level += 1
  end

  private

  def exp_to_next_level; (2 ** (2 + @level.next)) end

end