---
title: "锁帧与守夜：一个 KSU 模块里的两个小玩具"
date: 2026-10-30
draft: false
slug: "nannan-doze"
tags: ["Android", "Shell", "KSU", "logcat"]
categories: ["工具"]
description: "省电模式压帧怎么办？蓝牙网络共享忘了关怎么办？答案是让 shell 睁着一只眼。"
ShowToc: true
TocOpen: false
---

手机上的省电模式有一套自己的想法：开启的瞬间会把 `min_refresh_rate` 和 `peak_refresh_rate` 压到 60。理由充分——省电。但我不喜欢。帧率这件事，降下去就是降下去了，跟电量没关系。

蓝牙网络共享也有一套自己的想法：蓝牙一关，PAN 随之断开，但配置状态常常残留，下一次开蓝牙的时候又莫名其妙地活过来。

两个都不大，但都是那种「能自己收拾掉」的小事。于是往我平时维护的 KSU 模块 `nannan_doze` 里塞了两个守护进程。

## 一、省电模式锁帧

思路简单到没什么好讲的：盯着 `global low_power`，一旦是 1 就把两个刷新率钉回默认值。

```sh
check_fps() {
    LP=$(settings get global low_power 2>/dev/null)
    if [ "$LP" = "1" ]; then
        CUR_MIN=$(settings get $SYS min_refresh_rate 2>/dev/null)
        if [ "$CUR_MIN" != "$DEF_MIN" ]; then
            settings put $SYS min_refresh_rate $DEF_MIN
            settings put $SYS peak_refresh_rate $DEF_PEAK
        fi
    fi
}
```

关键在那个 `if [ "$CUR_MIN" != "$DEF_MIN" ]`——**只在值被压坏时才写**。这不只是省事，是后面能跑起来的前提。

## 二、蓝牙网络共享联动

盯 `global bluetooth_on`，1 → 0 的时候收尾巴，0 → 1 的时候装死：

```sh
if [ "$BT" = "0" ]; then
    svc bluetooth disable 2>/dev/null
    settings put global tethered_config_state 0
else
    # 不自动开共享，交给手动开关
    :
fi
```

蓝牙开着的时候不自动把网络共享打开，是个刻意的选择。共享这东西开了就吃流量，让手指决定比让脚本决定好。

## 三、从轮询到事件驱动

上面两段初版都是 `while true; do ...; sleep 5; done`。能用，但每五秒 fork 一堆 `settings` 子进程，怎么看怎么别扭。

后来在 `logcat -b events` 里翻到一行：

```
I commit_sys_config_file: [settings-1-0,28]
```

**任何 settings 写入都会留下这条事件。** 这意味着不必再问「变了吗变了吗」，只要挂个管道等它叫醒我：

```sh
logcat -b events | while IFS= read -r LINE; do
    case "$LINE" in
        *commit_sys_config_file*)
            [ -n "$LASTCHK" ] && [ $((SECONDS-LASTCHK)) -lt 2 ] && continue
            LASTCHK=$SECONDS
            check_fps
            check_bt
            ;;
    esac
done
```

三个值得注意的地方：

### 1. 防自激

我们自己 `settings put` 也会产生 `commit_sys_config_file`。理论上会陷入「写 → 事件 → 写 → 事件」的死循环。

但 check 函数只在值被压坏时才写。值正确的时候看一眼就走，不落笔。于是：写一次 → 事件 → check → 值对了 → 不写 → 收敛。数学上是个压缩映射，跑一次就到不动点。

### 2. 零 fork 节流

`$SECONDS` 是 mksh 内建变量，不需要 fork `date` 取时间戳。节流逻辑一行搞定：

```sh
[ $((SECONDS-LASTCHK)) -lt 2 ] && continue
```

省下来的都是真金白银的 CPU 唤醒。

### 3. 自愈

logcat 管道可能死——被 logd 转储踢掉、被内存压力杀掉、Android 大版本升级改行为。外层再套一个 while：

```sh
while true; do
    logcat -b events | while read LINE; do ...; done
    # 管道死了：兜底检查一次，然后睡 60 秒重启
    check_fps; check_bt
    sleep 60
done
```

事件驱动负责省电，轮询负责兜底。**两者不冲突，分层就行。**

## 后来

跑了一晚上，`nannan_watcher.log` 里只有寥寥几行：

```
2026-10-30 21:02:11 watcher v2 start fps=120/120 bt=1
2026-10-30 22:14:03 low_power keep_fps 120/120
2026-10-30 23:41:22 bt_off -> bt_tether down
```

省电模式开了一次，帧率被钉住了。蓝牙关了一次，尾巴收干净了。除此之外什么都没发生——这正是想要的样子。

挂机听事件的 shell 比五分钟一次的闹钟省电得多。道理谁都懂，但真正动手把它做对，还是要在 `logcat -b events` 里翻一会儿。

---

*模块本体在 GitHub 上，源码不长，`service.sh` 一个文件就是全部逻辑。*
