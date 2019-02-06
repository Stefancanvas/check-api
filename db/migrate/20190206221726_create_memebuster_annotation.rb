require 'sample_data'
include SampleData
class CreateMemebusterAnnotation < ActiveRecord::Migration
  def change
    text = DynamicAnnotation::FieldType.where(field_type: 'text').last
    image = DynamicAnnotation::FieldType.where(field_type: 'image_path').last
    at = create_annotation_type annotation_type: 'memebuster', label: 'Meme Generator Settings'
    create_field_instance annotation_type_object: at, name: 'memebuster_image', label: 'Image', field_type_object: image, optional: false
    create_field_instance annotation_type_object: at, name: 'memebuster_headline', label: 'Headline', field_type_object: text, optional: false
    create_field_instance annotation_type_object: at, name: 'memebuster_body', label: 'Body', field_type_object: text, optional: false
    create_field_instance annotation_type_object: at, name: 'memebuster_status', label: 'Status', field_type_object: text, optional: false
    create_field_instance annotation_type_object: at, name: 'memebuster_overlay', label: 'Overlay Color', field_type_object: text, optional: false
  end
end
