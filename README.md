# HyBridge
Simple Hysteria2 client and server configurator.  
  
**Dependencies:** gtk2 systemd  
**Lazarus:** LazBarcodes (from the Network Packet Manager)  
Working directory: ~/.config/hybridge  
Configurations/Certificates: ~/.config/hybridge/config  
![](https://github.com/AKotov-dev/HyBridge/blob/main/Screenshot2.png)  
### How to use it
+ Install the [hysteria2](https://v2.hysteria.network/docs/getting-started/Installation/) server on your VPS: `bash <(curl -fsSL https://get.hy2.sh/)`
+ Install `HyBridge` on your computer, enter your VPS `IP`, and click the `Create Client and Server` button
+ Be sure to save the provided configuration archive `config.tar.gz`
+ Copy the server configuration and certificate from `config.tar.gz` to `/etc/hysteria/{cert.pem,config.yaml}` on your VPS
+ Activate the Hysteria server on your VPS: `systemctl restart hysteria; systemctl enable hysteria`
+ Click the `Start` button in the `HyBridge` client window and access the free internet

The system proxy is configured automatically. Supported DEs: Budgie, GNOME, MATE, KDE. XFCE and LXDE support system proxy mode when [XDE-Proxy-GUI](https://github.com/AKotov-dev/xde-proxy-gui) is installed.
