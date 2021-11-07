class Notification < ApplicationRecord
  self.inheritance_column = nil
  enum type: { web: 'web' }

  scope :active, lambda { |from: Time.current, to: nil|
    activate_notifications = where(Notification.arel_table[:valid_from].lteq(from))
                             .where(Notification.arel_table[:valid_till].gt(from))
    activate_notifications = activate_notifications.where(':to BETWEEN valid_from and valid_till', to: to) if to
    activate_notifications
  }
end
