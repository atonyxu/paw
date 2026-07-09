cat > codespaces-desktop.sh << 'EOF'
#!/bin/bash

# ========================
# Codespaces Chromium + Openbox 桌面环境
# 用法: ./codespaces-desktop.sh [install|check]
# ========================

DIAGNOSE() {
    echo ""
    echo "=== 🔍 环境诊断报告 ==="
    echo "--- VNC / 桌面进程 ---"
    ps aux | grep -E "Xvnc|openbox|chromium" | grep -v grep || echo "❌ VNC/桌面进程未运行"
    
    echo "--- 端口监听状态 ---"
    ss -tlnp | grep -E "5901|6080" || echo "❌ 关键端口 (5901/6080) 未监听"
    
    echo "--- VNC 日志 (最后5行) ---"
    tail -5 ~/.vnc/*.log 2>/dev/null || echo "⚠️ 无 VNC 日志文件"
    
    echo "--- noVNC 日志 (最后5行) ---"
    tail -5 ~/noVNC/utils/novnc.log 2>/dev/null || echo "⚠️ 无 noVNC 日志文件"
    
    echo "--- xstartup 配置检查 ---"
    if [ -f ~/.vnc/xstartup ]; then
        ls -la ~/.vnc/xstartup
        head -3 ~/.vnc/xstartup
    else
        echo "❌ xstartup 文件不存在"
    fi
    
    echo "--- 端口可见性提醒 ---"
    echo "💡 若浏览器无法连接，请在 VS Code PORTS 面板将 6080 端口设为 Public"
    echo "=========================="
}

INSTALL() {
    echo "=== 🌐 开始配置 Chromium + Openbox 极简桌面 ==="

    # 1. 安装依赖
    echo "📦 正在安装基础组件与 Chromium..."
    sudo apt update -y
    sudo apt install -y openbox chromium-browser tigervnc-standalone-server tigervnc-common \
        expect git fonts-wqy-zenhei fonts-noto-cjk xdg-utils

    # 2. 自动设置 VNC 密码
    echo "🔑 正在设置 VNC 密码..."
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

    # 3. 配置启动脚本
    echo "⚙️ 正在配置 VNC 启动脚本..."
    cat > ~/.vnc/xstartup << 'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xsetroot -solid "#1e1e1e" &
chromium-browser --no-sandbox --disable-gpu --disable-dev-shm-usage --start-maximized &
exec openbox-session
XSTARTUP
    chmod +x ~/.vnc/xstartup

    # 4. 启动 VNC
    echo "🖥️ 正在启动 VNC 服务..."
    vncserver -geometry 1280x720 -depth 24

    # 5. 启动 noVNC
    echo "🌐 正在启动 noVNC 代理..."
    if [ ! -d "noVNC" ]; then
        git clone https://github.com/novnc/noVNC.git
    fi
    cd noVNC/utils
    nohup ./novnc_proxy --vnc localhost:5901 > novnc.log 2>&1 &

    echo "✅ 部署完成！VNC 密码: 123456"
    echo "💡 请通过 VS Code PORTS 面板打开 6080 端口"
    
    # 部署后自动执行诊断
    DIAGNOSE
}

# 主入口
case "${1:-install}" in
    install) INSTALL ;;
    check)   DIAGNOSE ;;
    *)
        echo "用法: $0 [install|check]"
        echo "  install - 安装桌面环境并自动诊断"
        echo "  check   - 仅执行环境诊断"
        exit 1
        ;;
esac
EOF

chmod +x codespaces-desktop.sh
