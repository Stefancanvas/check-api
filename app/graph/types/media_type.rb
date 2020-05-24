MediaType = GraphqlCrudOperations.define_default_type do
  name 'Media'
  description 'The base item type for annotation activity.'

  interfaces [NodeIdentification.interface]

  field :url, types.String, 'Media URL'
  field :quote, types.String, 'Text claim'
  field :account_id, types.Int, 'Account id of publisher'
  field :project_id, types.Int, 'DEPRECATED' # TODO Remove
  field :dbid, types.Int, 'Database id of this record'
  field :domain, types.String, 'TODO'
  field :pusher_channel, types.String, 'Channel for push notifications'
  field :embed_path, types.String, 'TODO'
  field :thumbnail_path, types.String, 'Thumbnail representing this item' # TODO Rename to 'thumbnail'
  field :picture, types.String, 'Picture representing this item'
  field :type, types.String, 'TODO'
  field :file_path, types.String, 'TODO'

  field :account do
    type -> { AccountType }
    description 'Publisher of this item'

    resolve -> (media, _args, _ctx) {
      media.account
    }
  end

  field :metadata do
    type JsonStringType
    description 'Metadata about this item'

    resolve ->(media, _args, _ctx) {
      media.metadata
    }
  end
end
