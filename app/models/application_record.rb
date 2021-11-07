class ApplicationRecord < ActiveRecord::Base
  include IssuesTrackable
  self.abstract_class = true
end
