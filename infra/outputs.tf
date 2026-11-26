output "test_controller_public_ip" {
  description = "测试控制器公网 IP（SSH 登录压测用）"
  value       = huaweicloud_compute_eip_associate.test_controller.public_ip
}

output "sfs_turbo_export_locations" {
  description = "SFS Turbo 挂载点"
  value = {
    for fs_id, fs in huaweicloud_sfs_turbo.file_system : fs_id => fs.export_location
  }
}

output "sfs_turbo_ids" {
  description = "SFS Turbo 文件系统 ID（面板指标维度）"
  value = {
    for fs_id, fs in huaweicloud_sfs_turbo.file_system : fs_id => fs.id
  }
}