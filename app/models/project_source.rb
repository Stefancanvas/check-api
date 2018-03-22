class ProjectSource < ActiveRecord::Base

  attr_accessor :name

  belongs_to :project
  belongs_to :source
  belongs_to :user
  has_annotations

  include ProjectAssociation
  include Versioned

  validates_presence_of :source, :project
  validate :source_exists
  validates :source_id, uniqueness: { scope: :project_id }
  before_validation :set_account, on: :create

  after_create :add_elasticsearch_data, :add_elasticsearch_account

  def get_team
    p = self.project
    p.nil? ? [] : [p.team_id]
  end

  def collaborators
    self.annotators
  end

  def add_elasticsearch_data
    return if self.disable_es_callbacks || RequestStore.store[:disable_es_callbacks]
    p = self.project
    s = self.source
    ms = MediaSearch.new
    ms.id = Base64.encode64("ProjectSource/#{self.id}")
    ms.team_id = p.team.id
    ms.project_id = p.id
    ms.associated_type = self.source.class.name
    ms.set_es_annotated(self)
    ms.title = s.name
    ms.description = s.description
    ms.save!
  end

  def full_url
    "#{self.project.url}/source/#{self.id}"
  end

  private

  def set_account
    account = self.url.blank? ? nil : Account.create_for_source(self.url, self.source, false, self.disable_es_callbacks)
    unless account.nil?
      errors.add(:base, account.errors.to_a.to_sentence(locale: I18n.locale)) unless account.errors.empty?
      self.source ||= account.source
    end
  end

  def add_elasticsearch_account
    return if self.disable_es_callbacks || RequestStore.store[:disable_es_callbacks]
    parent = Base64.encode64("ProjectSource/#{self.id}")
    accounts = self.source.accounts
    accounts.each do |a|
      a.add_update_media_search_child('account_search', %w(ttile description username), {}, parent)
    end unless accounts.blank?
  end

  def source_exists
    unless self.url.blank?
      a = Account.new
      a.url = self.url
      a.valid?
      account = Account.where(url: a.url).last
      unless account.nil?
        if account.sources.joins(:project_sources).where('project_sources.project_id' => self.project_id).exists?
          errors.add(:base, I18n.t(:duplicate_source))
        end
      end
    end
  end

end
