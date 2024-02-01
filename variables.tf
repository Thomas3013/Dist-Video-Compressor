variable "name_prefix" {
    default = "postgresqlfs"
    description = "Prefix of the resource name."  
}
variable "location" {
    default = "eastus"
    description = "Location of the resource."
}

//vm variables
variable "linux_vm_size" {
  type        = string
  description = "Size (SKU) of the virtual machine to create"
}
variable "linux_admin_username" {
  type        = string
  description = "Username for Virtual Machine administrator account"
  default     = ""
}
variable "linux_admin_password" {
  type        = string
  description = "Password for Virtual Machine administrator account"
  default     = ""
}