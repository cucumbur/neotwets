class Twet
  def initialize(name, owner)
    @id = new_twet_id
    @firebase.set("twet/#{@id}", {owner:owner, name:name, hatched_on: Firebase::ServerValue::TIMESTAMP,
                                  level:1, experience:0, hungry:true})
    @firebase.update("user/#{owner}", {twet:@id})
  end

  def hungry=(is_hungry)
    firebase.update("twet/#{@id}")
  end
end