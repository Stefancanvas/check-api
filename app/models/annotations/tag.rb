class Tag < ActiveRecord::Base
  include AnnotationBase

  field :tag, String, presence: true
  field :full_tag, String, presence: true

  validates_presence_of :tag
  validates :data, uniqueness: { scope: [:annotated_type, :annotated_id], message: I18n.t(:already_exists) }, if: lambda { |t| t.id.blank? }

  before_validation :normalize_tag, :store_full_tag
  after_commit :add_update_elasticsearch_tag, on: [:create, :update]
  after_commit :destroy_elasticsearch_tag, on: :destroy

  def content
    { tag: self.tag }.to_json
  end

  private

  def normalize_tag
    self.tag = self.tag.gsub(/^#/, '') unless self.tag.nil?
  end

  def store_full_tag
    self.full_tag = self.tag
  end

  def add_update_elasticsearch_tag
    add_update_media_search_child('tag_search', %w(tag full_tag))
  end

  def destroy_elasticsearch_tag
    destroy_es_items(TagSearch)
  end

end
