class Relationship < ActiveRecord::Base
  belongs_to :source, class_name: 'ProjectMedia'
  belongs_to :target, class_name: 'ProjectMedia'

  serialize :relationship_type

  validate :relationship_type_is_valid

  private

  def relationship_type_is_valid
    begin
      value = self.relationship_type.with_indifferent_access
      raise('Relationship type is invalid') unless (value.keys == ['source', 'target'] && value['source'].is_a?(String) && value['target'].is_a?(String))
    rescue
      errors.add(:relationship_type)
    end
  end
end
