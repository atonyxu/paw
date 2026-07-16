#!/bin/bash

# ========================
# Codespaces 桌面环境 (智能检测版)
# 支持桌面: lxqt / xfce / mate
# 用法: ./run.sh [install|check|restart|uninstall] [lxqt|xfce|mate]
# ========================

DE_SKIP_INSTALL=false
VNC_RUNNING=false
NOVNC_RUNNING=false

DE_NAME="${2:-lxqt}"

# 各桌面环境对应的元包、会话启动命令、进程关键字
case "$DE_NAME" in
    lxqt)
        DE_PKG="lxqt-core"
        DE_START="startlxqt"
        DE_PROC="lxqt"
        ;;
    xfce)
        DE_PKG="xfce4"
        DE_START="startxfce4"
        DE_PROC="xfce4"
        ;;
    mate)
        DE_PKG="mate-desktop-environment-core"
        DE_START="mate-session"
        DE_PROC="mate"
        ;;
    *)
        echo "❌ 不支持的桌面环境: $DE_NAME"
        echo "   可选: lxqt / xfce / mate"
        exit 1
        ;;
esac

DE_INSTALLED=false
DE_LABEL="$(echo "$DE_NAME" | tr '[:lower:]' '[:upper:]')"

# 检测当前环境状态
DETECT_STATE() {
    if dpkg -l | grep -qE "^ii\s+${DE_PKG}\s"; then
        DE_INSTALLED=true
    fi

    if pgrep -f "Xvnc.*:1" > /dev/null; then
        VNC_RUNNING=true
    fi

    if pgrep -f "novnc_proxy" > /dev/null; then
        NOVNC_RUNNING=true
    fi
}

DIAGNOSE() {
    echo ""
    echo "=== 🔍 环境诊断报告 ($DE_LABEL) ==="
    echo "--- 组件状态 ---"
    $DE_INSTALLED && echo "✅ $DE_LABEL 桌面: 已安装" || echo "❌ $DE_LABEL 桌面: 未安装"
    $VNC_RUNNING && echo "✅ VNC Server (:1): 运行中" || echo "❌ VNC Server (:1): 未运行"
    $NOVNC_RUNNING && echo "✅ noVNC Proxy: 运行中" || echo "❌ noVNC Proxy: 未运行"

    echo "--- VNC / 桌面进程 ---"
    ps aux | grep -E "Xvnc|${DE_PROC}|falkon" | grep -v grep || echo "⚠️ 无相关进程"

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

STOP_SERVICES() {
    echo "🛑 正在停止 VNC / noVNC 服务..."
    pkill -f "Xvnc.*:1" 2>/dev/null
    pkill -f novnc_proxy 2>/dev/null
    sleep 1
}

INSTALL() {
    DETECT_STATE

    if [ "$DE_INSTALLED" = false ]; then
        echo "=== 📦 首次安装: $DE_LABEL + Falkon 桌面环境 ==="
        sudo apt update -y
        sudo apt install -y "$DE_PKG" falkon tigervnc-standalone-server tigervnc-common \
            expect git fonts-wqy-zenhei fonts-noto-cjk xdg-utils dbus-x11

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

        cat > ~/.vnc/xstartup << XSTARTUP
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec $DE_START
XSTARTUP
        chmod +x ~/.vnc/xstartup
    else
        echo "✅ $DE_LABEL 及依赖已安装，跳过 apt 步骤"
    fi

    if [ "$VNC_RUNNING" = false ]; then
        echo "🖥️ 正在启动 VNC 服务..."
        vncserver -kill :1 2>/dev/null
        vncserver :1 -geometry 1600x900 -depth 24
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
    echo "✅ $DE_LABEL 桌面就绪！VNC 密码: 123456"
    echo "💡 请通过 VS Code PORTS 面板打开 6080 端口访问桌面"
    echo "🌐 进入桌面后点击左下角菜单 → Internet → Falkon 启动浏览器"

    DIAGNOSE
}

RESTART() {
    echo "🔄 正在重启所有服务..."
    STOP_SERVICES
    INSTALL
}

UNINSTALL() {
    DETECT_STATE

    echo "=== 🗑️ 卸载 $DE_LABEL 桌面环境 ==="

    STOP_SERVICES

    if [ "$DE_INSTALLED" = true ]; then
        echo "📦 正在卸载 $DE_LABEL 相关软件包..."
        sudo apt purge -y "$DE_PKG" falkon
        sudo apt autoremove -y --purge
    else
        echo "✅ $DE_LABEL 未安装，跳过卸载"
    fi

    if [ -f ~/.vnc/xstartup ]; then
        echo "🧹 清理 xstartup 配置..."
        rm -f ~/.vnc/xstartup
    fi

    if [ -d "noVNC" ]; then
        echo "🧹 清理 noVNC 目录..."
        rm -rf noVNC
    fi

    echo ""
    echo "✅ $DE_LABEL 桌面环境卸载完成"
}

# 主入口
case "${1:-install}" in
    install)   INSTALL ;;
    check)     DETECT_STATE; DIAGNOSE ;;
    restart)   RESTART ;;
    uninstall) UNINSTALL ;;
    *)
        echo "用法: $0 [install|check|restart|uninstall] [lxqt|xfce|mate]"
        echo "  install   - 智能安装/恢复 (自动跳过已安装组件，默认 lxqt)"
        echo "  check     - 仅执行环境诊断"
        echo "  restart   - 强制重启所有服务"
        echo "  uninstall - 卸载指定的桌面环境及其组件"
        exit 1
        ;;
esac
