# 功能
自动调度Cloudflare DDNS反代IP 云端分钟更新一次
优选IP速度大于100Mbps，电信可能无法保障
全天99%在线

## 食用方式
### 准备工作
一台VPS（国内、国外均可），域名，cloudflare账号
### 步骤
1. 登录cloudflare账号，获取Global API Key
![](http://jinqians.com/wp-content/uploads/2023/12/1-1.png)

![](http://jinqians.com/wp-content/uploads/2023/12/2-scaled.jpg)

2. 登录VPS，复制下方命令执行
```shell
wget -O cloudflare-ddns.sh https://raw.githubusercontent.com/jinqians/cloudflare-ddns/main/cloudflare-ddns.sh && chmod +x cloudflare-ddns.sh && ./cloudflare-ddns.sh
```
输入自己的对应信息
![](http://jinqians.com/wp-content/uploads/2023/12/3.png)

3. 执行完成后按照提示，输入下方命令执行
```shell
./cloudflare.sh
```
到此，优选IP已绑定到自己的域名
