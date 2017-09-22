module SingletonAnnotationBase
  extend ActiveSupport::Concern
  include AnnotationBase

  def destroy
    # should revert singleton annotation
    widget = self.paper_trail.previous_version
    if widget.nil?
      # delete annotation if no versions
      Annotation.find(self.id).delete
    else
      widget.paper_trail.without_versioning do
        widget.save
        self.versions.last.destroy
      end
    end
  end

  private

  def set_annotator
    self.annotator = User.current unless User.current.nil?
  end
end
