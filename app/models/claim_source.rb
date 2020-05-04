class ClaimSource < ApplicationRecord

  belongs_to :media
  belongs_to :source

  validates_presence_of :media_id, :source_id
  validates :media_id, uniqueness: { scope: :source_id }
end
