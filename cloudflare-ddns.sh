#Telegram：@jinqians_chat
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# 欢迎信息
echo "欢迎使用Cloudflare 自动优选IP 群组：@jinqians_chat"
read -p "点击任意键继续.."

# 用户输入
read -p "请输入您的Cloudflare Global API Key（https://dash.cloudflare.com/profile/api-tokens）: " CFKEY
read -p "请输入您的Cloudflare 登录邮箱: " CFUSER
read -p "请输入您的Cloudflare DNS域名（一级域名）: " CFZONE_NAME
read -p "请输入您的Cloudflare DDNS域名（二级域名）: " CFRECORD_NAME

# 提醒信息
echo "请注意确保二级域名已随意添加一个解析并未开启代理"
read -p "按任意键回车继续.."

# 生成新的DDNS脚本文件
cat <<EOF > cloudflare.sh
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Cloudflare API credentials
CFKEY="$CFKEY"
CFUSER="$CFUSER"
CFZONE_NAME="$CFZONE_NAME"
CFRECORD_NAME="$CFRECORD_NAME"

# 记录类型，A(IPv4)|AAAA(IPv6)，默认为IPv4
CFRECORD_TYPE=A

# Cloudflare记录的TTL，介于120和86400秒之间
CFTTL=120

# 无视本地文件，无论如何都更新IP
FORCE=false

# 获取WAN IP的网站
WANIPSITE="https://cloudflare.vmshop.org/ipv4.php"

# 获取参数
while getopts k:u:h:z:t:f: opts; do
  case \${opts} in
    k) CFKEY=\${OPTARG} ;;
    u) CFUSER=\${OPTARG} ;;
    h) CFRECORD_NAME=\${OPTARG} ;;
    z) CFZONE_NAME=\${OPTARG} ;;
    t) CFRECORD_TYPE=\${OPTARG} ;;
    f) FORCE=\${OPTARG} ;;
  esac
done

# 如果必需的设置缺失，则退出
if [ "\$CFKEY" = "" ]; then
  echo "缺少API密钥，请在 https://www.cloudflare.com/a/account/my-account 获取"
  echo "并保存在 \${0} 或使用 -k 参数"
  exit 2
fi
if [ "\$CFUSER" = "" ]; then
  echo "缺少用户名，可能是您的电子邮件地址"
  echo "并保存在 \${0} 或使用 -u 参数"
  exit 2
fi
if [ "\$CFRECORD_NAME" = "" ]; then
  echo "缺少主机名，您想要更新哪个主机？"
  echo "保存在 \${0} 或使用 -h 参数"
  exit 2
fi

# 如果主机名不是完整域名
if [ "\$CFRECORD_NAME" != "\$CFZONE_NAME" ] && ! [ -z "\${CFRECORD_NAME##*\$CFZONE_NAME}" ]; then
  CFRECORD_NAME="\$CFRECORD_NAME.\$CFZONE_NAME"
  echo " => 主机名不是完整域名，假设为 \$CFRECORD_NAME"
fi

# 检查IP地址是否有效的函数
is_valid_ip() {
    local ip=\$1
    if [[ \$ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\$ ]]; then
        return 0
    else
        return 1
    fi
}

# 从主要IP源获取当前和旧的WAN IP
WAN_IP=\$(curl -s \$WANIPSITE | tr -d ' ' | tr -d '\n' | sed 's/<br>/\n/g' | head -n 1)

# 如果WAN_IP无效，尝试备用IP源
if ! is_valid_ip "\$WAN_IP"; then
    WAN_IP=\$(curl -s "https://cloudflare.vmshop.org/cloudflare-v4.php" | tr -d ' ' | tr -d '\n' | sed 's/<br>/\n/g' | head -n 1)
    if ! is_valid_ip "\$WAN_IP"; then
        echo "无法获取有效的IPv4地址"
        exit 1
    fi
fi

echo "IPv4 \$WAN_IP 已获取"

WAN_IP_FILE=\$HOME/.cf-wan_ip_\$CFRECORD_NAME.txt
if [ -f \$WAN_IP_FILE ]; then
  OLD_WAN_IP=\$(cat \$WAN_IP_FILE)
else
  echo "没有找到对应的输出文件 @jinqians_chat"
  OLD_WAN_IP=""
fi

# 如果WAN IP没有变化且没有强制更新标志，则退出
if [ "\$WAN_IP" = "\$OLD_WAN_IP" ] && [ "\$FORCE" = false ]; then
  echo "云端没有最新的优选IP @@jinqians_chat"
  exit 0
fi

# 获取区域标识符和记录标识符
ID_FILE=\$HOME/.cf-id_\$CFRECORD_NAME.txt
if [ -f \$ID_FILE ] && [ \$(wc -l \$ID_FILE | cut -d " " -f 1) == 4 ] \
  && [ "\$(sed -n '3,1p' "\$ID_FILE")" == "\$CFZONE_NAME" ] \
  && [ "\$(sed -n '4,1p' "\$ID_FILE")" == "\$CFRECORD_NAME" ]; then
    CFZONE_ID=\$(sed -n '1,1p' "\$ID_FILE")
    CFRECORD_ID=\$(sed -n '2,1p' "\$ID_FILE")
else
    echo "正在更新区域标识符和记录标识符"
    CFZONE_ID=\$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=\$CFZONE_NAME" -H "X-Auth-Email: \$CFUSER" -H "X-Auth-Key: \$CFKEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    CFRECORD_ID=\$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/\$CFZONE_ID/dns_records?name=\$CFRECORD_NAME" -H "X-Auth-Email: \$CFUSER" -H "X-Auth-Key: \$CFKEY" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*' | head -1 )
    echo "\$CFZONE_ID" > \$ID_FILE
    echo "\$CFRECORD_ID" >> \$ID_FILE
    echo "\$CFZONE_NAME" >> \$ID_FILE
    echo "\$CFRECORD_NAME" >> \$ID_FILE
fi

# 更新Cloudflare DNS记录
if is_valid_ip "\$WAN_IP"; then
    RESPONSE=\$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/\$CFZONE_ID/dns_records/\$CFRECORD_ID" \
      -H "X-Auth-Email: \$CFUSER" \
      -H "X-Auth-Key: \$CFKEY" \
      -H "Content-Type: application/json" \
      --data "{\"id\":\"\$CFZONE_ID\",\"type\":\"\$CFRECORD_TYPE\",\"name\":\"\$CFRECORD_NAME\",\"content\":\"\$WAN_IP\", \"ttl\":\$CFTTL}")

    if [ "\$RESPONSE" != "\${RESPONSE%success*}" ] && [ "\$(echo \$RESPONSE | grep "\"success\":true")" != "" ]; then
      echo "已同步到Cloudflare！"
      echo \$WAN_IP > \$WAN_IP_FILE
    else
      echo '出现错误 :('
      echo "响应: \$RESPONSE"
      exit 1
    fi
else
    echo "IP地址无效，无法更新DNS记录"
    exit 1
fi
EOF

# 赋予新脚本执行权限
chmod +x cloudflare.sh

# 设置计划任务
(crontab -l 2>/dev/null; echo "* * * * * $(pwd)/cloudflare.sh") | crontab -

# 完成提示
echo "成功生成对应的配置文件，请执行 ./cloudflare.sh"

# 提示用户计划任务已设置
echo "计划任务已设置，脚本将每分钟运行一次。"
