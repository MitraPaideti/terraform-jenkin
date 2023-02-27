locals {
  max_subnet_length = max(
    length(var.private_subnets)
  )
  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length

  vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this[0].id, "")

  create_vpc = var.create_vpc && var.putin_khuylo
}

data "aws_availability_zones" "available" {}


################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  count = local.create_vpc ? 1 : 0

  cidr_block          = var.cidr
  ipv4_ipam_pool_id   = var.ipv4_ipam_pool_id
  ipv4_netmask_length = var.ipv4_netmask_length


  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.vpc_tags,
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = local.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  # Do not turn this into `local.vpc_id`
  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

# resource "aws_default_security_group" "this" {
#   count = local.create_vpc && var.manage_default_security_group ? 1 : 0

#   vpc_id = aws_vpc.this[0].id

#   dynamic "ingress" {
#     for_each = var.default_security_group_ingress
#     content {
#       self             = lookup(ingress.value, "self", null)
#       cidr_blocks      = compact(split(",", lookup(ingress.value, "cidr_blocks", "")))
#       ipv6_cidr_blocks = compact(split(",", lookup(ingress.value, "ipv6_cidr_blocks", "")))
#       prefix_list_ids  = compact(split(",", lookup(ingress.value, "prefix_list_ids", "")))
#       security_groups  = compact(split(",", lookup(ingress.value, "security_groups", "")))
#       description      = lookup(ingress.value, "description", null)
#       from_port        = lookup(ingress.value, "from_port", 0)
#       to_port          = lookup(ingress.value, "to_port", 0)
#       protocol         = lookup(ingress.value, "protocol", "-1")
#     }
#   }

#   dynamic "egress" {
#     for_each = var.default_security_group_egress
#     content {
#       self             = lookup(egress.value, "self", null)
#       cidr_blocks      = compact(split(",", lookup(egress.value, "cidr_blocks", "")))
#       ipv6_cidr_blocks = compact(split(",", lookup(egress.value, "ipv6_cidr_blocks", "")))
#       prefix_list_ids  = compact(split(",", lookup(egress.value, "prefix_list_ids", "")))
#       security_groups  = compact(split(",", lookup(egress.value, "security_groups", "")))
#       description      = lookup(egress.value, "description", null)
#       from_port        = lookup(egress.value, "from_port", 0)
#       to_port          = lookup(egress.value, "to_port", 0)
#       protocol         = lookup(egress.value, "protocol", "-1")
#     }
#   }

#   tags = merge(
#     { "Name" = coalesce(var.default_security_group_name, var.name) },
#     var.tags,
#     var.default_security_group_tags,
#   )
# }


################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count = local.create_vpc && var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.igw_tags,
  )
}

################################################################################
# Default route
################################################################################

# resource "aws_default_route_table" "default" {
#   count = local.create_vpc && var.manage_default_route_table ? 1 : 0

#   default_route_table_id = aws_vpc.this[0].default_route_table_id
#   propagating_vgws       = var.default_route_table_propagating_vgws

#   dynamic "route" {
#     for_each = var.default_route_table_routes
#     content {
#       # One of the following destinations must be provided
#       cidr_block      = route.value.cidr_block
#       ipv6_cidr_block = lookup(route.value, "ipv6_cidr_block", null)

#       # One of the following targets must be provided
#       egress_only_gateway_id    = lookup(route.value, "egress_only_gateway_id", null)
#       gateway_id                = lookup(route.value, "gateway_id", null)
#       instance_id               = lookup(route.value, "instance_id", null)
#       nat_gateway_id            = lookup(route.value, "nat_gateway_id", null)
#       network_interface_id      = lookup(route.value, "network_interface_id", null)
#       transit_gateway_id        = lookup(route.value, "transit_gateway_id", null)
#       vpc_endpoint_id           = lookup(route.value, "vpc_endpoint_id", null)
#       vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
#     }
#   }

#   timeouts {
#     create = "5m"
#     update = "5m"
#   }

#   tags = merge(
#     { "Name" = coalesce(var.default_route_table_name, var.name) },
#     var.tags,
#     var.default_route_table_tags,
#   )
# }

################################################################################
# Publiс routes
################################################################################

resource "aws_route_table" "public" {
  count = local.create_vpc && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = "${var.name}-${var.public_subnet_suffix}" },
    var.tags,
    var.public_route_table_tags,
  )
}

resource "aws_route" "public_internet_gateway" {
  count = local.create_vpc && var.create_igw && length(var.public_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

################################################################################
# Private routes
# There are as many routing tables as the number of NAT gateways
################################################################################

# resource "aws_route_table" "private" {
#   count = local.create_vpc && local.max_subnet_length > 0 ? local.nat_gateway_count : 0

#   vpc_id = local.vpc_id

#   tags = merge(
#     {
#       "Name" = var.single_nat_gateway ? "${var.name}-${var.private_subnet_suffix}" : format(
#         "${var.name}-${var.private_subnet_suffix}-%s",
#         element(var.azs, count.index),
#       )
#     },
#     var.tags,
#     var.private_route_table_tags,
#   )
# }


################################################################################
# Public subnet
################################################################################

resource "aws_subnet" "public" {
  count = local.create_vpc && length(var.public_subnets) > 0 && (false == var.one_nat_gateway_per_az || length(var.public_subnets) >= length(var.azs)) ? length(var.public_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = element(concat(var.public_subnets, [""]), count.index)
  availability_zone               = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  #  availability_zone = element(var.azs, count.index)
  # availability_zone= "us-west-2a"
  
  map_public_ip_on_launch         = var.map_public_ip_on_launch
  
  tags = merge(
    {
      Name = try(
        var.public_subnet_names[count.index],
        format("${var.name}-${var.public_subnet_suffix}-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.public_subnet_tags,
    lookup(var.public_subnet_tags_per_az, element(var.azs, count.index), {})
  )
}

################################################################################
# Private subnet
################################################################################

resource "aws_subnet" "private" {
  count = local.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.private_subnets[count.index]
  availability_zone               = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  #  availability_zone = element(var.azs, count.index)
  # availability_zone="us-west-2c"
  # availability_zone = "us-west-2b" 
  tags = merge(
    {
      Name = try(
        var.private_subnet_names[count.index],
        format("${var.name}-${var.private_subnet_suffix}-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.private_subnet_tags,
    lookup(var.private_subnet_tags_per_az, element(var.azs, count.index), {})
  )
}

################################################################################
# NAT Gateway
################################################################################

locals {
  nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : try(aws_eip.nat[*].id, [])
}

resource "aws_eip" "nat" {
  count = local.create_vpc && var.enable_nat_gateway && false == var.reuse_nat_ips ? local.nat_gateway_count : 0

  vpc = true

  tags = merge(
    {
      "Name" = format(
        "${var.name}-%s",
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    var.tags,
    var.nat_eip_tags,
  )
}

resource "aws_nat_gateway" "this" {
  count = local.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

   allocation_id = element(
      local.nat_gateway_ips,
     var.single_nat_gateway ? 0 : count.index,
  )
  subnet_id = element(
    aws_subnet.public[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )

  tags = merge(
    {
      "Name" = format(
        "${var.name}-%s",
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    var.tags,
    var.nat_gateway_tags,
  )

  depends_on = [aws_internet_gateway.this]
}


resource "aws_route_table_association" "public" {
  count = local.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count = local.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id = element(aws_subnet.private[*].id, count.index)
  # route_table_id = element(
  #   aws_route_table.private[*].id,
  #   var.single_nat_gateway ? 0 : count.index,
  # )
  route_table_id = aws_route_table.public[0].id
}