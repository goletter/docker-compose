# Certbot（Let's Encrypt）

用 Docker 为任意域名申请 SSL 证书（webroot 模式），并按站点同步到 `/etc/nginx/cert/<域名>/`。

## 目录

```text
certbot/
├── cert.sh              # 申请证书脚本
├── renew.sh             # 续签 + 同步到 /etc/nginx/cert
├── docker-compose.yml   # 挂载证书 / webroot
├── README.md
└── data/                # 运行后生成（勿提交敏感内容）
    ├── letsencrypt/     # Certbot 原始证书
    ├── letsencrypt-lib/
    └── webroot/         # 默认 ACME 验证目录
```

## 前置条件

1. 域名已解析到本机公网 IP
2. 80 端口可从外网访问
3. nginx 已配置 ACME 验证路径，且 **webroot 与 Certbot 写入目录一致**

### nginx 示例

```nginx
server {
    listen 80;
    listen 443 ssl;
    server_name meta.wewallmedia.com;
    root /var/www/meta.wewallmedia.com;

    # 必须放在 location / 之前（尤其是 SPA 的 try_files）
    location /.well-known/acme-challenge/ {
        root /var/www/meta.wewallmedia.com;  # 与 WEBROOT 一致
        default_type text/plain;
        try_files $uri =404;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    ssl_certificate     /etc/nginx/cert/meta.wewallmedia.com/meta.wewallmedia.com.pem;
    ssl_certificate_key /etc/nginx/cert/meta.wewallmedia.com/meta.wewallmedia.com.key;
}
```

### 申请前自测

```bash
mkdir -p /var/www/meta.wewallmedia.com/.well-known/acme-challenge
echo ok > /var/www/meta.wewallmedia.com/.well-known/acme-challenge/ping
curl -i http://meta.wewallmedia.com/.well-known/acme-challenge/ping
```

应返回纯文本 `ok`，不能是 HTML 或 404。

## 使用方法

```bash
cd certbot
chmod +x cert.sh renew.sh   # 仅首次需要
```

### 方式一：站点目录作 webroot（推荐，与上面 nginx 一致）

```bash
WEBROOT=/var/www/meta.wewallmedia.com \
  ./cert.sh meta.wewallmedia.com your@email.com
```

### 方式二：使用默认 `./data/webroot`

此时 nginx 的 ACME `root` 必须指向该目录在容器/宿主机上的对应路径（例如挂载为 `/var/www/certbot`）：

```bash
./cert.sh example.com your@email.com
```

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `WEBROOT` | `./data/webroot` | ACME 验证文件目录，须与 nginx `root` 一致 |
| `NGINX_CERT_DIR` | `/etc/nginx/cert` | 按站点存放证书的目录 |
| `RELOAD_NGINX` | `1` | 续签后是否自动 reload nginx（`renew.sh`） |
| `FORCE_RENEW` | `0` | 设为 `1` 强制续签（测试用） |

示例：

```bash
WEBROOT=/var/www/example.com \
NGINX_CERT_DIR=/etc/nginx/cert \
  ./cert.sh example.com your@email.com
```

写入 `/etc/nginx/cert` 通常需要 root 权限：

```bash
sudo WEBROOT=/var/www/example.com ./cert.sh example.com your@email.com
```

### 方式三：docker compose

```bash
docker compose run --rm certbot certonly --webroot \
  --webroot-path /var/www/certbot \
  -d example.com \
  --email your@email.com \
  --agree-tos --no-eff-email
```

compose 默认 webroot 为 `./data/webroot`；证书不会自动拷到 `/etc/nginx/cert`，请优先使用 `cert.sh`。

## 证书输出位置

申请成功后：

```text
# Certbot 原始文件
./data/letsencrypt/live/<域名>/fullchain.pem
./data/letsencrypt/live/<域名>/privkey.pem

# 同步到 nginx（按站点区分）
/etc/nginx/cert/<域名>/<域名>.pem
/etc/nginx/cert/<域名>/<域名>.key
```

例如：

```text
/etc/nginx/cert/meta.wewallmedia.com/meta.wewallmedia.com.pem
/etc/nginx/cert/meta.wewallmedia.com/meta.wewallmedia.com.key
```

nginx：

```nginx
ssl_certificate     /etc/nginx/cert/meta.wewallmedia.com/meta.wewallmedia.com.pem;
ssl_certificate_key /etc/nginx/cert/meta.wewallmedia.com/meta.wewallmedia.com.key;
```

改完后执行：

```bash
nginx -t && nginx -s reload
```

## 续签

Let's Encrypt 证书有效期约 90 天，建议提前自动续签。`renew.sh` 会：

1. 执行 `certbot renew`（未到期会跳过，属正常）
2. 把 `./data/letsencrypt/live/<域名>/` 同步到 `/etc/nginx/cert/<域名>/`
3. 尝试 `nginx -s reload`（或 reload 名为 `nginx` 的容器）

### 手动续签

```bash
cd certbot

# WEBROOT 须与申请时一致
WEBROOT=/var/www/meta.wewallmedia.com \
  ./renew.sh

# 需要写 /etc/nginx/cert 时
sudo WEBROOT=/var/www/meta.wewallmedia.com ./renew.sh
```

强制续签（测试）：

```bash
FORCE_RENEW=1 WEBROOT=/var/www/meta.wewallmedia.com ./renew.sh
```

只同步证书、不 reload nginx：

```bash
RELOAD_NGINX=0 ./renew.sh
```

### 定时续签（cron）

每天检查一次即可（未到期不会真正续签）：

```bash
sudo crontab -e
```

加入（按实际路径和 WEBROOT 修改）：

```cron
0 3 * * * WEBROOT=/var/www/meta.wewallmedia.com /var/www/docker-compose/certbot/renew.sh >> /var/log/certbot-renew.log 2>&1
```

若多个站点共用同一个 webroot（例如都挂 `./data/webroot`），一条 cron 即可续签全部；若各站点 `WEBROOT` 不同，需为每种 webroot 各配一条，或统一改成共享 webroot。

### docker compose 续签

```bash
docker compose run --rm certbot renew \
  --webroot --webroot-path /var/www/certbot
```

compose 不会自动同步到 `/etc/nginx/cert`，续签后请再跑 `./renew.sh`，或优先直接用 `renew.sh`。

## 常见问题

### LE 返回 SPA 的 HTML

缺少 `location /.well-known/acme-challenge/`，请求被 `try_files ... /index.html` 吃掉。按上文补上该 location。

### LE / curl 返回 404

Certbot 写入目录与 nginx 读取目录不一致。确认：

- `WEBROOT` = nginx ACME 的 `root`
- 文件实际存在于：`<WEBROOT>/.well-known/acme-challenge/<token>`

### standalone 备选（临时停掉 80 端口服务）

```bash
docker run --rm -it \
  -p 80:80 \
  -v "$(pwd)/data/letsencrypt:/etc/letsencrypt" \
  -v "$(pwd)/data/letsencrypt-lib:/var/lib/letsencrypt" \
  certbot/certbot certonly --standalone \
  -d example.com \
  --email your@email.com \
  --agree-tos --no-eff-email
```

成功后再手动拷贝到 `/etc/nginx/cert/<域名>/`，或继续用 `cert.sh`（webroot）走完整流程。
