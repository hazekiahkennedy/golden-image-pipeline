variable "yourname" {
  description = "Your name, lowercase, no spaces. Used in all resource names."
  type        = string
}

variable "location" {
  type    = string
  default = "westus2"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "golden-images"
    managed_by = "terraform"
  }
}
