macro json_property(attr)
  {% if attr.is_a?(TypeDeclaration) %}
  @[JSON::Field(key: {{attr.var.id.camelcase.id}})]
  property {{attr.var.id}} : {{attr.type}} {% if attr.value %}= {{attr.value}}{% end %}
  {% elsif attr.is_a?(Assign) %}
  @[JSON::Field(key: {{attr.target.id.camelcase.id}})]
  property {{attr.target.id}} = {{attr.value}}
  {% end %}
end

macro json_property(key, attr)
  @[JSON::Field(key: {{key}})]
  {% if attr.is_a?(TypeDeclaration) %}
  property {{attr.var.id.underscore.id}} : {{attr.type}} {% if attr.value %}= {{attr.value}}{% end %}
  {% elsif attr.is_a?(Assign) %}
  property {{attr.target.id.underscore.id}} = {{attr.value}}
  {% end %}
end
