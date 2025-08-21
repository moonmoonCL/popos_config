#!/bin/bash

# ERGO K860 蓝牙键盘符号链接创建脚本
# 用途: 为 ERGO K860 键盘在 /dev/input/by-id/ 下创建固定名称的符号链接
# 作者: 自动生成
# 使用: sudo ./setup_k860_link.sh

set -e # 遇到错误立即退出

# 配置
KEYBOARD_NAME="ERGO K860 Keyboard"
LINK_NAME="bluetooth-ergo-k860-keyboard"
BY_ID_DIR="/dev/input/by-id"
LINK_PATH="$BY_ID_DIR/$LINK_NAME"

echo "正在扫描 ERGO K860 键盘..."

# 从 /proc/bus/input/devices 中找到 ERGO K860 键盘对应的 event 设备
EVENT_DEVICE=""
while IFS= read -r line; do
  if [[ $line == *"Name=\"$KEYBOARD_NAME\""* ]]; then
    # 找到了设备，读取下一行的 Handlers 信息
    while IFS= read -r handlers_line; do
      if [[ $handlers_line == H:* ]]; then
        # 从 Handlers 行中提取 event 编号
        if [[ $handlers_line =~ event([0-9]+) ]]; then
          EVENT_NUM="${BASH_REMATCH[1]}"
          EVENT_DEVICE="/dev/input/event$EVENT_NUM"
          break
        fi
      elif [[ $handlers_line == I:* ]]; then
        # 如果读到下一个设备的开始，说明没找到 event
        break
      fi
    done
    break
  fi
done </proc/bus/input/devices

# 检查是否找到了设备
if [[ -z "$EVENT_DEVICE" ]]; then
  echo "错误: 未找到 '$KEYBOARD_NAME' 设备"
  echo "请确保 ERGO K860 键盘已连接并配对"
  exit 1
fi

echo "找到设备: $EVENT_DEVICE"

# 检查 event 设备是否存在
if [[ ! -e "$EVENT_DEVICE" ]]; then
  echo "错误: 设备文件 $EVENT_DEVICE 不存在"
  exit 1
fi

# 检查是否有权限操作 /dev/input/by-id 目录
if [[ ! -w "$BY_ID_DIR" ]]; then
  echo "错误: 没有权限写入 $BY_ID_DIR 目录"
  echo "请使用 sudo 运行此脚本: sudo $0"
  exit 1
fi

# 如果符号链接已存在，先删除
if [[ -L "$LINK_PATH" ]]; then
  echo "删除现有符号链接: $LINK_PATH"
  rm "$LINK_PATH"
elif [[ -e "$LINK_PATH" ]]; then
  echo "警告: $LINK_PATH 存在但不是符号链接，请手动检查"
  exit 1
fi

# 创建符号链接 (相对路径)
EVENT_BASENAME=$(basename "$EVENT_DEVICE")
echo "创建符号链接: $LINK_PATH -> ../$EVENT_BASENAME"
ln -s "../$EVENT_BASENAME" "$LINK_PATH"

# 验证符号链接
if [[ -L "$LINK_PATH" && -e "$LINK_PATH" ]]; then
  echo "✓ 符号链接创建成功!"
  echo "  链接路径: $LINK_PATH"
  echo "  目标设备: $EVENT_DEVICE"
  echo ""
  echo "你现在可以在 kmonad 配置中使用:"
  echo "  input (device-file \"$LINK_PATH\")"
else
  echo "✗ 符号链接创建失败"
  exit 1
fi

# 显示当前 by-id 目录内容
echo ""
echo "当前 /dev/input/by-id/ 目录内容:"
ls -la "$BY_ID_DIR/" | grep -E "(^total|$LINK_NAME)"

exec kmonad "/home/bakaya/.config/kmonad/config.kbd" >/dev/null 2>&1
