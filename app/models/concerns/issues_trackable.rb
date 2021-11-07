module IssuesTrackable
  extend ActiveSupport::Concern

  included do
    # @conditions [Proc, Symbol, String]
    def self.track_issues(high: [], medium: [])
      define_method :high_severity_issues do
        issue_collection_for(high)
      end

      define_method :medium_severity_issues do
        issue_collection_for(medium)
      end
    end
  end

  private

  def issue_collection_for(conditions)
    [].tap do |array|
      conditions.each do |condition|
        response = condition.is_a?(Symbol) ? send(condition) : condition.call(self)
        next unless response

        array << response
      end
    end
  end
end