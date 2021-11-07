class AwsPeeringConnection < ApplicationRecord
  belongs_to :aws_account
  has_one :accepter_vpc, class_name: 'AwsPeeredAccepterVpc', dependent: :destroy
  has_one :requester_vpc, class_name: 'AwsPeeredRequesterVpc', dependent: :destroy
end