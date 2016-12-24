MediaType = GraphqlCrudOperations.define_default_type do
  name 'Media'
  description 'Media type'

  interfaces [NodeIdentification.interface]

  field :id do
    type !types.ID

    resolve -> (media, _args, _ctx) {
      media.relay_id
    }
  end

  field :updated_at, types.String
  field :url, types.String
  field :quote, types.String
  field :account_id, types.Int
  field :project_id, types.Int
  field :dbid, types.Int
  field :domain, types.String
  field :pusher_channel, types.String

  field :account do
    type -> { AccountType }

    resolve -> (media, _args, _ctx) {
      media.account
    }
  end

  connection :projects, -> { ProjectType.connection_type } do
    resolve -> (media, _args, _ctx) {
      media.projects
    }
  end

  instance_exec :media, &GraphqlCrudOperations.field_verification_statuses
end


