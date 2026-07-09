cat > setup_desktop.sh << 'EOF'
#!/bin/bash

echo "=== 🚀 开始自动配置 Codespaces 桌面环境 ==="

# 1. 更新软件源并安装必要依赖（包括 expect 用于自动交互）
echo "📦 正在安装基础依赖..."
sudo apt update -y
sudo apt install -y lxqt-core tigervnc-standalone-server tigervnc-common expect git

# 2. 自动设置 VNC 密码（这里将密码硬编码为 123456，你可以根据需要修改）
echo "🔑 正在自动设置 VNC 密码..."
mkdir -p ~/.vnc
expect << EOD
spawn vncpasswd
expect "Password:"
send "123456\r"
expect "Verify:"
send "123456\r"
expect "Would you like to enter a view-only password (y/n)?"
send "n\r"
expect eof
EOD

# 3. 配置 VNC 启动脚本，指定启动 LXQt 桌面环境
echo "⚙️ 正在配置 VNC 启动脚本..."
cat > ~/.vnc/xstartup << 'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startlxqt &
XSTARTUP
chmod +x ~/.vnc/xstartup

# 4. 启动 VNC 服务（设置分辨率为 1280x720 以适应浏览器窗口）
echo "🖥️ 正在启动 TigerVNC 服务..."
vncserver -geometry 1280x720 -depth 24

# 5. 克隆并启动 noVNC 代理服务
echo "🌐 正在启动 noVNC 网页代理..."
if [ ! -d "noVNC" ]; then
    git clone https://github.com/novnc/noVNC.git
fi
cd noVNC/utils
# 将 VNC 的 5901 端口转发到 6080 端口，并在后台运行
nohup ./novnc_proxy --vnc localhost:5901 > novnc.log 2>&1 &

echo "✅ 桌面环境部署完成！"
echo "💡 请在 VS Code 底部的【端口(PORTS)】面板中，找到 6080 端口，点击地球图标在浏览器中打开。"
echo "🔑 连接时请输入 VNC 密码：123456"
EOF

# 赋予脚本执行权限并运行
chmod +x setup_desktop.sh
./setup_desktop.sh
