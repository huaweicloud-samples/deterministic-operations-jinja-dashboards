variable "region" {
  description = "华为云区域"
  type        = string
  default     = "cn-north-4"
}

variable "sfs_turbo_size" {
  description = "SFS Turbo 文件系统容量（GB）"
  type        = number
  default     = 500
}

variable "ssh_allowed_cidr" {
  description = "允许 SSH 登录测试控制器的来源网段（建议改为你的出口 IP）"
  type        = string
  default     = "0.0.0.0/0"
}

variable "test_controller" {
  description = "测试控制器规格（flavor_id 显式指定，保证运行规格可复现；按需调整）"
  type = object({
    cpu       = number
    memory    = number
    flavor_id = string
  })
  default = {
    cpu       = 2
    memory    = 4
    flavor_id = "s6.large.2"
  }
}