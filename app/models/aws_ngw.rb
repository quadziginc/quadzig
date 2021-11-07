class AwsNgw < ApplicationRecord
  belongs_to :aws_account

  def default_label
    'NGW'
  end
end