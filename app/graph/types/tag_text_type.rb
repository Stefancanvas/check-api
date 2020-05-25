TagTextType = GraphqlCrudOperations.define_default_type do
  name 'TagText'
  description 'The content of a tag. Multiple items can refer to the same TagText via the Tag annotation.'

  interfaces [NodeIdentification.interface]

  field :dbid, types.Int, 'Database id of this record'
  field :text, types.String
  field :tags_count, types.Int
  field :teamwide, types.Boolean # TODO Remove
end
