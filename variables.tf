variable "key_name" {
  description = "Name of the key pair to use for EC2"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key file for SSH"
  type        = string
}

variable "bucket_name" {
  description = "Name of the existing S3 bucket"
  type        = string
  default = "one2n-mybucket"
}
