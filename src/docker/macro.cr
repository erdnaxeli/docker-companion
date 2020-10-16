macro json_property(attr, type)
  @[JSON::Field(key: {{attr.id.camelcase.id}})]
  property {{attr}} : {{type}}
end

macro json_property(attr, key, type)

  @[JSON::Field(key: {{key}})]
  property {{attr}} : {{type}}
end
