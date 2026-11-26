# ============================================================================
# 监控面板示例 · 基础设施层（VPC / SFS Turbo / ECS 测试控制器）
# ============================================================================
# 本文件创建示例使用的文件系统与测试控制器实例：
#   - VPC + 子网 + 安全组（NFS 2049 与 SSH 仅限放行运维者 IP）
#   - SFS Turbo × 2（作为监控对象，打上 Application=dash-demo 标签供模板渲染脚本发现）
#   - ECS 测试控制器（挂载两个文件系统，用于运行压测产生监控数据）
# 监控面板资源由 templates/dashboards.tf.jinja 渲染生成后追加到本目录
# （运行 scripts/render_vars.py + scripts/render_template.py，详见 README）。
# ============================================================================

locals {
  project = {
    name = "dash-demo"
    env  = "demo"
  }
  global = {
    tags = {
      Application = local.project.name
      ProjectEnv  = local.project.env
    }
  }
  file_systems = {
    fs1 = {
      mount_directory = "/mnt/fs1"
    },
    fs2 = {
      mount_directory = "/mnt/fs2"
    },
  }
  test_controller = {
    user_data = templatefile("${path.module}/../scripts/user-data.tftpl", {
      sfs_file_systems = local.file_systems
      sfs_mount_points = {
        for fs_id, fs in huaweicloud_sfs_turbo.file_system : fs_id => fs.export_location
      }
    })
  }
}

# ----------------------------------------------------------------------------
# VPC / 子网 / 安全组
# ----------------------------------------------------------------------------

resource "huaweicloud_vpc" "this" {
  name = "${local.project.name}-${local.project.env}-vpc"
  cidr = "10.99.0.0/22"
}

resource "huaweicloud_vpc_subnet" "private" {
  name       = "${local.project.name}-${local.project.env}-private"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = "10.99.1.0/24"
  gateway_ip = "10.99.1.1"
}

resource "huaweicloud_vpc_subnet" "public" {
  name       = "${local.project.name}-${local.project.env}-public"
  vpc_id     = huaweicloud_vpc.this.id
  cidr       = "10.99.2.0/24"
  gateway_ip = "10.99.2.1"
}

resource "huaweicloud_networking_secgroup" "this" {
  name        = "${local.project.name}-${local.project.env}-sg"
  description = "Security group for the monitoring dashboard demo"
}

# NFS 挂载流量：仅在安全组内部互通
resource "huaweicloud_networking_secgroup_rule" "nfs_ingress" {
  security_group_id = huaweicloud_networking_secgroup.this.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_group_id   = huaweicloud_networking_secgroup.this.id
  description       = "NFS ingress within security group"
}

resource "huaweicloud_networking_secgroup_rule" "nfs_egress" {
  security_group_id = huaweicloud_networking_secgroup.this.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 2049
  port_range_max    = 2049
  remote_group_id   = huaweicloud_networking_secgroup.this.id
  description       = "NFS egress within security group"
}

# HTTPS 出站：软件源与系统更新
resource "huaweicloud_networking_secgroup_rule" "https_egress" {
  security_group_id = huaweicloud_networking_secgroup.this.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "HTTPS egress"
}

# HTTP 出站：软件源
resource "huaweicloud_networking_secgroup_rule" "http_egress" {
  security_group_id = huaweicloud_networking_secgroup.this.id
  direction         = "egress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  description       = "HTTP egress"
}

# ----------------------------------------------------------------------------
# SFS Turbo 文件系统（监控对象）
# ----------------------------------------------------------------------------

resource "huaweicloud_sfs_turbo" "file_system" {
  for_each = local.file_systems

  name              = "${local.project.name}-${local.project.env}-${each.key}"
  size              = var.sfs_turbo_size
  share_proto       = "NFS"
  availability_zone = data.huaweicloud_availability_zones.this.names[0]
  vpc_id            = huaweicloud_vpc.this.id
  subnet_id         = huaweicloud_vpc_subnet.private.id
  security_group_id = huaweicloud_networking_secgroup.this.id

  tags = local.global.tags
}

# ----------------------------------------------------------------------------
# 测试控制器 ECS
# ----------------------------------------------------------------------------

data "huaweicloud_availability_zones" "this" {}

data "huaweicloud_images_image" "this" {
  name        = "Ubuntu 22.04 server 64bit"
  most_recent = true
}

resource "huaweicloud_compute_instance" "test_controller" {
  name               = "${local.project.name}-${local.project.env}-test-controller"
  image_id           = data.huaweicloud_images_image.this.id
  flavor_id          = var.test_controller.flavor_id
  security_group_ids = [huaweicloud_networking_secgroup.this.id]

  network {
    uuid = huaweicloud_vpc_subnet.public.id
  }

  user_data = base64encode(local.test_controller.user_data)

  tags = local.global.tags
}

# 公网 IP：用于 SSH 登录测试控制器执行压测（安全组仅放行运维者 IP）
resource "huaweicloud_vpc_eip" "test_controller" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "${local.project.name}-${local.project.env}-eip"
    size        = 5
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "huaweicloud_compute_eip_associate" "test_controller" {
  public_ip   = huaweicloud_vpc_eip.test_controller.address
  instance_id = huaweicloud_compute_instance.test_controller.id
}

# SSH 入口：仅放行运维者 IP（部署时替换为你的出口 IP；默认示例放行常见网段，生产使用请收紧）
resource "huaweicloud_networking_secgroup_rule" "ssh_ingress" {
  security_group_id = huaweicloud_networking_secgroup.this.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_allowed_cidr
  description       = "SSH ingress from operator"
}