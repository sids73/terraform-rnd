variable "px-config-bucket-name" {
    type = string
    description = "Name of the bucket that contains the px-config file"
    default = "transporter-px-config-bucket"
}

variable "dummy-lambda-code-bucket-name" {
    type = string
    description = "Name of the bucket that contains the dummy lambda code zip"
    default = "lambda-dummy-code"
}

variable dummy-lambda-code-zip {
    type = string
    description = "Name of the dummy lambda code zip"
    default = "dummy-lambda-code.zip"
}

variable "px-config-bucket-acl" {
    type = string
    description = "Access control list for the px-config bucket"
    default = "private"
}
variable "px-config-bucket-tags" {
    type = map(string)
    description = "Tags for the px-config bucket"
    default = {
        Name = "transporter-px-config-bucket"
        Environment = "Sandbox"
    }
  
}