variable "name" {
  description = "Name prefix for the VPC and related resources"
  type        = string
}

variable "cidr" {
  description = "IPv4 CIDR for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zone names to use (e.g. us-west-2a)"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs (one per AZ is typical)"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs (one per AZ is typical)"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway(s) for private subnet egress"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all AZs (cheaper; fine for learning / non-HA)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Additional tags for public subnets (merged with common tags)"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Additional tags for private subnets (merged with common tags)"
  type        = map(string)
  default     = {}
}