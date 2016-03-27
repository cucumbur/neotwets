class Twegg
  attr_accessor :owner, :adjective, :color, :pattern, :created_on, :incubated, :incubated_on, :hatched

  def initialize(owner)
    data = YAML.load_file('world.yaml') #TODO there must be a better way to decouple this
    @adjective = data['adjective'].sample
    @color = data['color'].sample
    @pattern = data['pattern'].sample
    @owner = owner
    @created_on = Time.now
    @incubated = false
  end

end