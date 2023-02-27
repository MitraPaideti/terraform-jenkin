# module "vpc" {
#   source = "./modules/vpc"

#   name = "main"
#   cidr = "10.0.0.0/16"

#   azs = [ "us-west-2a","us-west-2b" ]
# private_subnets = ["10.0.1.0/24"]
# public_subnets  = ["10.0.4.0/24","10.0.3.0/24"]
    
#     enable_nat_gateway = true
#   tags = {
#         "Environment"="staging"
#   }
  
# }

module "ec2" {
source  = "./modules/ec2"
ami                  = "ami-02b6dc10ba68a0ea7"
instance_type        = "t2.micro"
# availability_zone    = "us-west-2"
}