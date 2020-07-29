# TODO Rename to 'TeamMediaType'
ProjectMediaType = GraphqlCrudOperations.define_default_type do
  name 'ProjectMedia'
  description 'Association between a team and a media.'

  interfaces [NodeIdentification.interface]

  field :media_id, types.Int, 'Media this item is associated with (database id)'
  field :url, types.String, 'Media URL' # TODO Delegate to Media
  field :quote, types.String, 'Text claim' # TODO Delegate to Media
  field :oembed, JsonStringType, 'Embed information for this media'
  field :archived, types.Boolean, 'Is this item in trash?' # TODO Rename to 'is_archived'
  field :author_role, types.String # TODO Merge with 'user'?
  field :report_type, types.String # TODO Merge with 'type'?
  field :title, types.String, 'Title'
  field :description, types.String, 'Description'
  field :picture, types.String, 'Picture'
  field :requests_count, types.Int, 'Count of requests made for this item'
  field :requests_related_count, types.Int, 'Count of requests made for this item and all related items' do
    resolve -> (project_media, _args, _ctx) {
      project_media.demand
    }
  end
  field :related_count, types.Int, 'Count of related items' do
    resolve -> (project_media, _args, _ctx) {
      project_media.linked_items_count
    }
  end
  field :last_seen, types.String, 'when was this item last requested' # TODO Convert to date and rename to 'last_requested'
  field :status, types.String, 'Workflow status'
  field :share_count, types.Int, 'Count of social shares'
  field :team_id, types.Int, 'Team this item is associated with (database id)'

  field :type, types.String, 'Item type'  do # TODO Delegate to Media
    resolve -> (project_media, _args, _ctx) {
      project_media.media.type
    }
  end

  field :permissions, types.String, 'CRUD permissions of this record for current user' do
    resolve -> (project_media, _args, ctx) {
      PermissionsLoader.for(ctx[:ability]).load(project_media.id).then do |pm|
        pm.cached_permissions || pm.permissions
      end
    }
  end

  # TODO Simplify
  field :tasks_count, JsonStringType, 'Counts of tasks: all, open, completed' do
    resolve -> (project_media, _args, _ctx) {
      {
        all: project_media.all_tasks.size,
        open: project_media.open_tasks.size,
        completed: project_media.completed_tasks.size
      }
    }
  end

  # TODO Delegate to Media
  field :domain, types.String do
    resolve -> (project_media, _args, _ctx) {
      RecordLoader.for(Media).load(project_media.media_id).then do |media|
        media.respond_to?(:domain) ? media.domain : ''
      end
    }
  end

  # TODO Delegate to Media
  field :account, -> { AccountType }, 'Account this item is associated with' do
    resolve -> (project_media, _args, _ctx) {
      RecordLoader.for(Media).load(project_media.media_id).then do |media|
        RecordLoader.for(Account).load(media.account_id)
      end
    }
  end

  field :team, -> { TeamType }, 'Team this item is associated with' do
    resolve -> (project_media, _args, _ctx) {
      RecordLoader.for(Team).load(project_media.team_id)
    }
  end

  # TODO: Merge with :projects below
  field :project_media_project, ProjectMediaProjectType, 'Project associated with this item' do
    argument :project_id, !types.Int, 'Project to match'
    resolve -> (project_media, args, _ctx) {
      ProjectMediaProject.where(project_media_id: project_media.id, project_id: args['project_id']).last
    }
  end

  # TODO: Rewrite
  connection :projects, -> { ProjectType.connection_type }, 'Projects associated with this item' do
    resolve -> (project_media, _args, _ctx) {
      project_media.projects
    }
  end

  field :media, -> { MediaType }, 'Media associated with this item' do
    resolve -> (project_media, _args, _ctx) {
      RecordLoader.for(Media).load(project_media.media_id)
    }
  end

  instance_exec :project_media, &GraphqlCrudOperations.field_log
  instance_exec :project_media, &GraphqlCrudOperations.field_annotations

  # TODO Replace with annotations + argument
  connection :tags, -> { TagType.connection_type }, 'Item tags' do
    resolve ->(project_media, _args, _ctx) {
      project_media.get_annotations('tag').map(&:load)
    }
  end

  # TODO Replace with annotations + argument
  connection :tasks, -> { TaskType.connection_type }, 'Item tasks' do
    resolve ->(project_media, _args, _ctx) {
      tasks = Task.where(annotation_type: 'task', annotated_type: 'ProjectMedia', annotated_id: project_media.id)
      # Order tasks by order field
      ids = tasks.to_a.sort_by{ |obj| obj.order ||= 0 }.map(&:id)
      values = []
      ids.each_with_index do |id, i|
        values << "(#{id}, #{i})"
      end
      return tasks if values.empty?
      joins = ActiveRecord::Base.send(:sanitize_sql_array,
        ["JOIN (VALUES %s) AS x(value, order_number) ON %s.id = x.value", values.join(', '), 'annotations'])
      tasks.joins(joins).order('x.order_number')
    }
  end

  # TODO Replace with annotations + argument
  connection :comments, -> { CommentType.connection_type }, 'Item comments' do
    resolve ->(project_media, _args, _ctx) {
      project_media.get_annotations('comment').map(&:load)
    }
  end

  field :metadata, JsonStringType, 'Item metadata'

  # TODO Merge this and 'last_status_obj' into 'status'
  field :last_status, types.String do
    resolve ->(project_media, _args, _ctx) {
      project_media.last_status
    }
  end
  field :last_status_obj, -> { DynamicType } do
    resolve -> (project_media, _args, _ctx) {
      obj = project_media.last_status_obj
      obj.is_a?(Dynamic) ? obj : obj.load
    }
  end

  # TODO Remove overridden logic
  field :overridden, JsonStringType do
    resolve ->(project_media, _args, _ctx) {
      project_media.overridden
    }
  end

  # TODO Replace with annotations + argument
  field :language, types.String, 'Item language' do
    resolve ->(project_media, _args, _ctx) {
      project_media.get_dynamic_annotation('language')&.get_field('language')&.send(:to_s)
    }
  end

  # TODO Replace with annotations + argument
  field :language_code do
    type types.String

    resolve ->(project_media, _args, _ctx) {
      project_media.get_dynamic_annotation('language')&.get_field_value('language')
    }
  end

  connection :assignments, -> { AnnotationType.connection_type }, 'List of assigned annotations for this item' do
    argument :user_id, !types.Int, 'Filter by given user database id'
    argument :annotation_type, !types.String, 'Filter by given annotation type'

    resolve ->(project_media, args, _ctx) {
      Annotation.joins(:assignments).where('annotations.annotated_type' => 'ProjectMedia', 'annotations.annotated_id' => project_media.id, 'assignments.user_id' => args['user_id'], 'annotations.annotation_type' => args['annotation_type'])
    }
  end

  # TODO Merge this and 'relationships' and 'secondary_items' and 'targets_by_users'
  field :relationship do
    type RelationshipType

    resolve ->(project_media, _args, _ctx) {
      Relationship.where(target_id: project_media.id).first || Relationship.where(source_id: project_media.id).first
    }
  end

  field :relationships do
    type -> { RelationshipsType }

    resolve -> (project_media, _args, _ctx) do
      OpenStruct.new({
        id: project_media.id,
        target_id: Relationship.target_id(project_media),
        source_id: Relationship.source_id(project_media),
        project_media_id: project_media.id,
        targets_count: project_media.targets_count,
        sources_count: project_media.sources_count
      })
    end
  end

  connection :secondary_items, -> { ProjectMediaType.connection_type } do
    argument :source_type, types.String
    argument :target_type, types.String

    resolve -> (project_media, args, _ctx) {
      related_items = ProjectMedia.joins('INNER JOIN relationships ON relationships.target_id = project_medias.id').where('relationships.source_id' => project_media.id)
      related_items = related_items.where('relationships.relationship_type = ?', { source: args['source_type'], target: args['target_type'] }.to_yaml) if args['source_type'] && args['target_type']
      related_items
    }
  end

  connection :targets_by_users, -> { ProjectMediaType.connection_type }

  # TODO Change type of [types.Int]
  field :project_ids, JsonStringType, 'Projects associated with this item (database ids)'

  field :dbid, types.Int, 'Database id of this record'

  field :user_id, types.Int, 'Database id of record creator'

  field :user, -> { UserType }, 'Record creator' do
    resolve -> (project_media, _args, ctx) {
      RecordLoader.for(User).load(project_media.user_id).then do |user|
        ability = ctx[:ability] || Ability.new
        user if ability.can?(:read, user)
      end
    }
  end

  field :pusher_channel, types.String, 'Channel for push notifications' do
    resolve -> (project_media, _args, _ctx) {
      RecordLoader.for(Media).load(project_media.media_id).then do |media|
        media.pusher_channel
      end
    }
  end
end
