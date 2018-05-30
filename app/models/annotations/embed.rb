class Embed < ActiveRecord::Base
  include SingletonAnnotationBase

  field :title
  field :description
  field :embed
  field :username
  field :published_at, Integer
  field :refreshes_count, Integer

  after_commit :update_elasticsearch_embed, :send_slack_notification, on: [:create, :update]

  def content
    {
      title: self.title,
      description: self.description,
      username: self.username,
      published_at: self.published_at,
      embed: self.embed
    }.to_json
  end

  def slack_notification_message
    return if self.annotated_type != 'ProjectMedia' || !self.title_is_overridden?
    data = self.overridden_data
    I18n.t(:slack_save_embed,
      user: Bot::Slack.to_slack(User.current.name),
      from: Bot::Slack.to_slack(data[0]['title']),
      to: Bot::Slack.to_slack_url(self.annotated_client_url, data[1]['title']),
      project: Bot::Slack.to_slack(self.annotated.project.title)
    )
  end

  def title_is_overridden?
    overriden = false
    v = self.versions.last
    unless v.nil?
      data = self.get_overridden_data(v)
      overriden = (!data[0].blank? && !data[0]['title'].nil? && data[0]['title'] != data[1]['title'])
    end
    self.overridden_data = data if overriden
    overriden
  end

  def get_overridden_data(version)
    data = version.changeset['data'] || []
    # Get title from pender if Link has only one version
    if self.annotated.media.type == 'Link' and self.versions.size == 1
      pender = self.annotated.media.get_annotations('embed').last
      data[0]['title'] = pender['data']['title'] unless pender.nil?
    end
    data
  end

  def overridden_data
    @overridden_data
  end

  def overridden_data=(data)
    @overridden_data = data
  end

  def update_elasticsearch_embed
    keys = %w(title description)
    if self.annotated_type == 'ProjectMedia'
      data = {}
      media_embed = self.annotated.media.embed
      overridden = self.annotated.overridden
      keys.each do |k|
        data[k] = [media_embed[k], self.send(k)] if overridden[k]
      end
      self.update_media_search(keys, data)
    end
    if self.annotated_type == 'Media' && self.annotated.type == 'Link'
      self.annotated.project_medias.each do |pm|
        em = pm.get_annotations('embed').last
        self.update_media_search(keys, {}, pm) if em.nil?
      end
    end
  end

  def embed_for_registration_account(data)
    unless data.nil?
      embed = {}
      embed['author_name'] = data.dig('info', 'name')
      embed['author_picture'] = data.dig('info', 'image')
      embed['author_url'] = data['url']
      embed['description'] = data.dig('info', 'description')
      embed['picture'] = data.dig('info', 'image')
      embed['provider'] = data['provider']
      embed['title'] = data.dig('info', 'name')
      embed['url'] = data['url']
      embed['username'] = data.dig('info', 'nickname') || data.dig('info', 'name')
      embed['parsed_at'] = Time.now
      embed['pender'] = false
      self.embed = embed.to_json
      self.save!
    end
  end

end
