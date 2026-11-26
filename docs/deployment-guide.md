# 部署指导书

本指导书带你从零开始部署完整的「Jinja 模板驱动云监控面板」示例，包含基础设施与监控面板两部分。

## 目录

1. [前置条件](#1-前置条件)
2. [获取代码](#2-获取代码)
3. [配置凭证](#3-配置凭证)
4. [部署基础设施](#4-部署基础设施)
5. [渲染监控面板](#5-渲染监控面板)
6. [验证](#6-验证)
7. [清理资源](#7-清理资源)

---

## 1. 前置条件

| 项 | 要求 | 说明 |
|---|---|---|
| 账号 | 已开通华为云账号并完成实名认证 | 个人 / 企业均可 |
| 权限 | IAM `Tenant Administrator` 或足够权限 | 创建 VPC / SFS Turbo / ECS / CES 面板 |
| Region | `cn-north-4`（北京四） | 也可按需修改 `infra/variables.tf` |
| Terraform | `>= 1.5` | IaC 工具 |
| Python3 | `>= 3.9` | 渲染脚本运行环境 |
| pip | 最新版 | 安装依赖 |
| Jinja2 | `>= 3.1` | 模板渲染库 |
| 华为云 Python SDK | `huaweicloudsdksfsturbo` `huaweicloudsdkcore` | 资源发现脚本依赖 |

## 2. 获取代码

```bash
git clone <repo-https-url> deterministic-operations-jinja-dashboards
cd deterministic-operations-jinja-dashboards
```

## 3. 配置凭证

在华为云控制台「我的凭证」页面创建访问密钥，然后导出为环境变量：

```bash
export HW_ACCESS_KEY="<your-access-key>"
export HW_SECRET_KEY="<your-secret-key>"
```

> 不要将凭据写入任何代码或配置文件。

## 4. 部署基础设施

```bash
cd infra
terraform init
terraform plan
terraform apply -auto-approve
```

预期输出：`Apply complete! Resources: N added, 0 changed, 0 destroyed.`

部署内容：

- VPC + 私有/公有子网 + 安全组（NFS 2049 内部互通、HTTPS/HTTP 出站、SSH 入站）
- SFS Turbo 文件系统 ×2（打上 `Application=dash-demo` 标签，作为监控对象）
- 测试控制器 ECS（挂载两个文件系统，用于压测）
- 弹性公网 IP（绑定测试控制器，用于 SSH 登录压测）

```bash
terraform output test_controller_public_ip
```

记录测试控制器的公网 IP，后续压测使用。

## 5. 渲染监控面板

回到仓库根目录，创建虚拟环境并安装依赖：

```bash
cd ..
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install jinja2 huaweicloudsdkcore huaweicloudsdksfsturbo
```

渲染模板变量文件（按标签发现文件系统）：

```bash
python3 scripts/render_vars.py \
  --tag-key Application --tag-value dash-demo \
  --template dashboards.vars.jinja \
  --rendered-file dashboards.vars.json
```

渲染 Terraform 面板定义：

```bash
python3 scripts/render_template.py \
  --template dashboards.tf.jinja \
  --template-vars dashboards.vars.json \
  --rendered-file infra/dashboards.tf
```

把生成的面板注册到华为云云监控：

```bash
cd infra
terraform plan
terraform apply -auto-approve
```

预期输出：`Apply complete! Resources: M added, 0 changed, 0 destroyed.`（M 为面板容器 + 组件数量）

## 6. 验证

### 6.1 面板可见

登录华为云控制台 → 云监控服务（CES）→ 监控面板，应看到三个面板：

- `dash-demo-demo-sfs-resource-tier-3`（资源层）
- `dash-demo-demo-sfs-service-tier-2`（服务层）
- `dash-demo-demo-sfs-system-tier-1`（系统层）

### 6.2 产生监控数据

SSH 登录测试控制器（公网 IP 来自 `terraform output test_controller_public_ip`，安全组已放行你的来源 IP）：

```bash
ssh <user>@<test_controller_public_ip>
```

确认文件系统已挂载：

```bash
df -h | grep /mnt
```

运行 fio 压测产生读写指标（根据你的挂载点调整目录）：

```bash
fio --name=random-read-write \
  --directory=/mnt/fs1:/mnt/fs2 \
  --rw=randrw --bsrange=100k-1M,1M-4M \
  --size=4G --numjobs=16 --end_fsync=1
```

### 6.3 面板呈现

压测进行中刷新控制台面板，资源层 / 服务层面板应显示读写吞吐与 IOPS 曲线，系统层面板显示容量使用。

## 7. 清理资源

```bash
cd infra
terraform destroy -auto-approve
```

预期输出：`Destroy complete! Resources: N destroyed.`

> 该命令释放 Terraform 追踪的全部资源（VPC / SFS Turbo / ECS / EIP / 面板），避免残留。