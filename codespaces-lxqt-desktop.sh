#!/bin/bash

# ========================
# Codespaces LXQt + Falkon 桌面环境 (智能检测版)
# 用法: ./codespaces-lxqt-desktop.sh [install|check|restart]
# ========================

FALKON_INSTALLED=false
VNC_RUNNING=false
NOVNC_RUNNING=false

# 检测当前环境状态
DETECT_STATE() {
    # 1. 检测 Falkon 是否已安装
    if dpkg -l | grep -q "^ii\s\+falkon\s"; then
        FALKON_INSTALLED=true
    fi
    
    # 2. 检测 VNC Server 是否运行
    if pgrep -x "Xvnc" > /dev/null; then
        VNC_RUNNING=true
    fi
    
    # 3. 检测 noVNC 代理是否运行
    if pgrep -f "novnc_proxy" > /dev/null; then
        NOVNC_RUNNING=true
    fi
}

DIAGNOSE() {
    echo ""
    echo "=== 🔍 环境诊断报告 ==="
    echo "--- 组件状态 ---"
    $FALKON_INSTALLED && echo "✅ Falkon 浏览器: 已安装" || echo "❌ Falkon 浏览器: 未安装"
    $VNC_RUNNING && echo "✅ VNC Server: 运行中" || echo "❌ VNC Server: 未运行"
    $NOVNC_RUNNING && echo "✅ noVNC Proxy: 运行中" || echo "❌ noVNC Proxy: 未运行"
    
    echo "--- VNC / 桌面进程 ---"
    ps aux | grep -E "Xvnc|lxqt|falkon" | grep -v grep || echo "⚠️ 无相关进程"
    
    echo "--- 端口监听状态 ---"
    ss -tlnp | grep -E "5901|6080" || echo "❌ 关键端口 (5901/6080) 未监听"
    
    echo "--- VNC 日志 (最后5行) ---"
    tail -5 ~/.vnc/*.log 2>/dev/null || echo "⚠️ 无 VNC 日志文件"
    
    echo "--- xstartup 配置检查 ---"
    if [ -f ~/.vnc/xstartup ]; then
        ls -la ~/.vnc/xstartup
    else
        echo "❌ xstartup 文件不存在"
    fi
    
    echo "--- 端口可见性提醒 ---"
    echo "💡 若浏览器无法连接，请在 VS Code PORTS 面板将 6080 端口设为 Public"
    echo "=========================="
}

INSTALL() {
    DETECT_STATE
    
    # === 阶段1: 软件包安装 (仅在未安装时执行) ===
    if [ "$FALKON_INSTALLED" = false ]; then
        echo "=== 📦 首次安装: LXQt + Falkon 桌面环境 ==="
        sudo apt update -y
        sudo apt install -y lxqt-core falkon tigervnc-standalone-server tigervnc-common \
            expect git fonts-wqy-zenhei fonts-noto-cjk xdg-utils dbus-x11
        
        # 设置 VNC 密码 (仅首次需要)
        if [ ! -f ~/.vnc/passwd ]; then
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
        fi
        
        # 写入 xstartup (幂等操作)
        cat > ~/.vnc/xstartup << 'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startlxqt
XSTARTUP
        chmod +x ~/.vnc/xstartup
    else
        echo "✅ Falkon 及依赖已安装，跳过 apt 步骤"
    fi
    
    # === 阶段2: 服务启动 (无论是否重装都检查并补启) ===
    if [ "$VNC_RUNNING" = false ]; then
        echo "🖥️ 正在启动 VNC 服务..."
        vncserver -geometry 1920x1080 -depth 24
    else
        echo "✅ VNC 服务已在运行"
    fi
    
    if [ "$NOVNC_RUNNING" = false ]; then
        echo "🌐 正在启动 noVNC 代理..."
        if [ ! -d "noVNC" ]; then
            git clone https://github.com/novnc/noVNC.git
        fi
        cd noVNC/utils
        nohup ./novnc_proxy --vnc localhost:5901 > novnc.log 2>&1 &
        cd ../..
    else
        echo "✅ noVNC 代理已在运行"
    fi
    
    echo ""
    echo "✅ LXQt 桌面就绪！VNC 密码: 123456"
    echo "💡 请通过 VS Code PORTS 面板打开 6080 端口访问桌面"
    echo "🌐 进入桌面后点击左下角菜单 → Internet → Falkon 启动浏览器"
    
    DIAGNOSE
}

RESTART() {
    echo "🔄 正在重启所有服务..."
    pkill -x Xvnc 2>/dev/null
    pkill -f novnc_proxy 2>/dev/null
    sleep 1
    INSTALL
}

# 主入口
case "${1:-install}" in
    install) INSTALL ;;
    check)   DETECT_STATE; DIAGNOSE ;;
    restart) RESTART ;;
    *)
        echo "用法: $0 [install|check|restart]"
        echo "  install - 智能安装/恢复 (自动跳过已安装组件)"
        echo "  check   - 仅执行环境诊断"
        echo "  restart - 强制重启所有服务"
        exit 1
        ;;
esac
