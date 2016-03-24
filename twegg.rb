class Twegg
  attr_accessor :owner, :adjective, :color, :pattern, :incubated, :incubated_on, :hatched

  def initialize(owner)
    data = YAML.load_file('world.yaml') # bad!!! DECIDE HOW TO DECOMPOSE THIS
    @adjective = data['adjective'].sample
    @color = data['color'].sample
    @pattern = data['pattern'].sample
    @owner = owner
    $firebase.set("twegg/#{owner}", {owner:owner, adjective:@adjective, color:@color,
                                     pattern:@pattern, incubated:false, hatched:false})
  end

end