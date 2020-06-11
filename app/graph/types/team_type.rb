TeamType = GraphqlCrudOperations.define_default_type do
  name 'Team'
  description 'The workspace where annotation activity occurs.'

  interfaces [NodeIdentification.interface]

  field :archived, types.Boolean # TODO Rename to 'is_archived'
  field :private, types.Boolean # TODO Rename to 'is_private'
  field :avatar, types.String, 'Picture' # TODO Rename to 'picture'
  field :name, !types.String
  field :slug, !types.String
  field :description, types.String
  field :members_count, types.Int
  field :projects_count, types.Int
  field :get_slack_notifications_enabled, types.String # TODO Rename to 'slack_notifications_enabled'
  field :get_slack_webhook, types.String # TODO Rename to 'slack_webhook'
  field :get_slack_channel, types.String # TODO Rename to 'slack_channel'
  field :get_embed_whitelist, types.String  # TODO Rename to 'embed_whitelist'
  field :get_report_design_image_template, types.String # TODO Rename to 'report_design_image_template'
  field :get_disclaimer, types.String # TODO Rename to 'report_disclaimer' or 'report_settings.disclaimer'
  field :get_introduction, types.String # TODO Rename to 'report_introduction' or 'report_settings.introduction'
  field :get_use_disclaimer, types.Boolean # TODO Rename to 'report_use_disclaimer' or 'report_settings.use_disclaimer'
  field :get_use_introduction, types.Boolean # TODO Rename to 'report_use_introduction' or 'report_settings.use_introduction'
  field :search_id, types.String # TODO What's that for?
  field :search, CheckSearchType
  field :check_search_trash, CheckSearchType # TODO Rename to 'search_trash'
  field :trash_size, JsonStringType # TODO What's that as opposed to `trash_count`?
  field :public_team_id, types.String
  field :permissions_info, JsonStringType
  field :invited_mails, JsonStringType
  field :dynamic_search_fields_json_schema, JsonStringType
  field :get_rules, JsonStringType # TODO Rename to 'rules'
  field :rules_json_schema, types.String # TODO Why not a JsonStringType?
  field :rules_search_fields_json_schema, JsonStringType
  field :medias_count, types.Int
  field :trash_count, types.Int
  field :get_languages, types.String # TODO Rename to 'languages'
  field :get_language, types.String  # TODO Rename to 'language'

  field :public_team do
    type PublicTeamType

    resolve -> (team, _args, _ctx) do
      team
    end
  end

  field :verification_statuses do
    type JsonStringType

    resolve -> (team, _args, _ctx) do
      team.send('verification_statuses', 'media')
    end
  end

  connection :team_users, -> { TeamUserType.connection_type } do
    resolve -> (team, _args, _ctx) {
      team.team_users.where({ status: 'member' }).order('id ASC')
    }
  end

  connection :join_requests, -> { TeamUserType.connection_type } do
    resolve -> (team, _args, _ctx) {
      team.team_users.where({ status: 'requested' })
    }
  end

  connection :users, -> { UserType.connection_type } do
    resolve -> (team, _args, _ctx) {
      team.users
    }
  end

  connection :contacts, -> { ContactType.connection_type } do
    resolve -> (team, _args, _ctx) {
      team.contacts
    }
  end

  connection :projects, -> { ProjectType.connection_type } do
    resolve ->(team, _args, _ctx) {
      team.recent_projects
    }
  end

  connection :sources, -> { SourceType.connection_type } do
    resolve ->(team, _args, _ctx) {
      team.sources
    }
  end

  connection :team_bots, -> { BotUserType.connection_type } do
    resolve ->(team, _args, _ctx) {
      team.team_bots
    }
  end

  connection :team_bot_installations, -> { TeamBotInstallationType.connection_type } do
    resolve ->(team, _args, _ctx) {
      team.team_bot_installations
    }
  end

  connection :tag_texts, -> { TagTextType.connection_type } do
    resolve ->(team, _args, _ctx) {
      team.tag_texts
    }
  end

  connection :team_tasks, -> { TeamTaskType.connection_type } do
    resolve ->(team, _args, _ctx) {
      team.team_tasks.order('id ASC')
    }
  end

  field :dbid, types.Int, 'Database id of this record'
  field :permissions, types.String, 'CRUD permissions of this record for current user'
  field :pusher_channel, types.String, 'Channel for push notifications'
end
