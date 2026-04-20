#!/bin/bash
# qiaomu-anything-to-notebooklm Skill Installer

set -e

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  多源内容 → NotebookLM 安装程序${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. 检查依赖工具
echo -e "${YELLOW}[1/5] 检查依赖工具...${NC}"

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ 未找到 python3，请先安装 Python 3.9+${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
REQUIRED_VERSION="3.9"
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}❌ Python 版本过低（当前 $PYTHON_VERSION，需要 3.9+）${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python $PYTHON_VERSION${NC}"

if ! command -v uv &> /dev/null; then
    echo -e "${RED}❌ 未找到 uv，请先安装：https://docs.astral.sh/uv/getting-started/installation/${NC}"
    exit 1
fi
echo -e "${GREEN}✅ uv $(uv --version | awk '{print $2}')${NC}"

# 2. 克隆 wexin-read-mcp
echo ""
echo -e "${YELLOW}[2/5] 安装微信 MCP 服务器...${NC}"
MCP_DIR="$SKILL_DIR/wexin-read-mcp"

if [ -d "$MCP_DIR" ] && [ -f "$MCP_DIR/src/server.py" ]; then
    echo -e "${GREEN}✅ wexin-read-mcp 已存在${NC}"
else
    echo "正在克隆 wexin-read-mcp..."
    git clone https://github.com/Bwkyd/wexin-read-mcp.git "$MCP_DIR"
    echo -e "${GREEN}✅ 克隆完成${NC}"
fi

# 3. 安装 Python 依赖（通过 uv tool install / uvx）
echo ""
echo -e "${YELLOW}[3/5] 安装 Python 依赖...${NC}"

# MCP 依赖（fastmcp、playwright、beautifulsoup4、lxml）和 markitdown
# 用 uv pip 安装到用户 Python 环境（不污染系统）
UV_PYTHON_BIN="$(python3 -c 'import sys; print(sys.executable)')"

install_pkg() {
    local pkg="$1"
    local import_name="${2:-$1}"
    if python3 -c "import $import_name" 2>/dev/null; then
        echo -e "${GREEN}✅ $pkg 已安装${NC}"
    else
        echo "安装 $pkg ..."
        uv pip install --python "$UV_PYTHON_BIN" "$pkg"
        echo -e "${GREEN}✅ $pkg 安装完成${NC}"
    fi
}

install_pkg "fastmcp"
install_pkg "beautifulsoup4" "bs4"
install_pkg "lxml"
install_pkg "markitdown[all]" "markitdown"

# playwright 单独处理（需要额外安装浏览器）
if python3 -c "from playwright.sync_api import sync_playwright" 2>/dev/null; then
    echo -e "${GREEN}✅ playwright 已安装${NC}"
else
    echo "安装 playwright ..."
    uv pip install --python "$UV_PYTHON_BIN" "playwright>=1.40.0"
    echo -e "${GREEN}✅ playwright 安装完成${NC}"
fi

# MCP 服务器自身的依赖
if [ -f "$MCP_DIR/requirements.txt" ]; then
    echo "安装 wexin-read-mcp 依赖..."
    uv pip install --python "$UV_PYTHON_BIN" -r "$MCP_DIR/requirements.txt"
    echo -e "${GREEN}✅ wexin-read-mcp 依赖安装完成${NC}"
fi

# 4. 安装 Playwright Chromium
echo ""
echo -e "${YELLOW}[4/5] 检查 Playwright Chromium...${NC}"

if python3 -c "
from playwright.sync_api import sync_playwright
p = sync_playwright().start()
b = p.chromium.launch()
b.close()
p.stop()
" 2>/dev/null; then
    echo -e "${GREEN}✅ Playwright Chromium 已就绪${NC}"
else
    echo "安装 Chromium（可能需要几分钟）..."
    python3 -m playwright install chromium
    echo -e "${GREEN}✅ Chromium 安装完成${NC}"
fi

# 5. 检查 notebooklm CLI
echo ""
echo -e "${YELLOW}[5/5] 检查 NotebookLM CLI...${NC}"

if command -v notebooklm &> /dev/null; then
    NOTEBOOKLM_VERSION=$(notebooklm --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ notebooklm 已安装 ($NOTEBOOKLM_VERSION)${NC}"
else
    echo "安装 notebooklm-py..."
    uv tool install "git+https://github.com/teng-lin/notebooklm-py.git"
    if command -v notebooklm &> /dev/null; then
        echo -e "${GREEN}✅ notebooklm 安装完成${NC}"
    else
        echo -e "${RED}❌ notebooklm 安装失败，请手动安装：${NC}"
        echo "  uv tool install git+https://github.com/teng-lin/notebooklm-py.git"
        exit 1
    fi
fi

# 完成
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✅ 安装完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "📦 安装位置：$SKILL_DIR"
echo ""
echo -e "${BLUE}📝 下一步：配置 MCP 服务器${NC}"
echo ""
echo "运行以下命令将微信 MCP 添加到 Claude Code："
echo -e "${GREEN}  claude mcp add weixin-reader -s user -- python $MCP_DIR/src/server.py${NC}"
echo ""
echo -e "${BLUE}🔐 NotebookLM 认证（首次使用）${NC}"
echo ""
echo "  notebooklm login"
echo "  notebooklm list  # 验证认证成功"
echo ""
echo "⚠️  配置 MCP 后需要重启 Claude Code"
echo ""
echo "🚀 使用示例："
echo "  把这篇文章生成播客 https://mp.weixin.qq.com/s/xxx"
echo ""
