---
title: "锁帧与守夜"
date: 2026-10-30
draft: false
slug: "nannan-doze"
tags: ["Android", "Shell", "KSU"]
categories: ["记录"]
description: "手机的省电模式想把帧率压下去，我不想。于是写了一小段 shell 跟它较劲。"
ShowToc: true
TocOpen: false
---

晚上折腾手机，发现开了省电模式之后屏幕变得有点顿。低头一查，果然是刷新率被偷偷压到 60 了。

能理解，但不喜欢。

帧率对我来说是体验，不是电量。省电模式可以关后台、可以限性能，动屏幕就有点过分了。于是想了个笨办法——盯着它，它一压我就改回去。

## 一、省电模式锁帧

思路直白：盯着 `global low_power`，一旦是 1 就把刷新率钉回默认值。

写起来比想的还短，一个 if 就完了：

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

那个 `if [ "$CUR_MIN" != "$DEF_MIN" ]` 后面会救场，先记住。

## 二、顺手收拾了蓝牙

同一晚上还发现个小事：蓝牙网络共享关了之后配置会残留，下次开蓝牙又活过来。

也一起处理了。蓝牙关掉的时候顺手把尾巴收干净；蓝牙开着的时候**不**自动打开共享。共享吃流量，得让手指决定。

## 三、从「问」到「等」

上面两个初版都是 `while true; do ...; sleep 5; done`。能跑，但总觉得别扭——每五秒问一遍「变了吗变了吗」，像极了我妈催我写作业。

后来在 `logcat -b events` 里翻到一行：

```
I commit_sys_config_file: [settings-1-0,28]
```

**任何 settings 写入都会留下这条事件。** 那我不用问了，等它叫我就行。

```sh
logcat -b events | while IFS= read -r LINE; do
    case "$LINE" in
        *commit_sys_config_file*)
            check_fps
            check_bt
            ;;
    esac
done
```

改完的感觉很清爽。原来那个每五秒一轮的 shell 从 `top` 里消失了，只剩一个挂机等事件的管道。

三个细节，都是磨出来的：

### 防自激

我们自己写 settings 也会产生这个事件。理论上会陷入「写 → 事件 → 写」的死循环。

好在 check 函数只在值被压坏时才写。值正确就看一眼走人。写一次 → 事件 → check → 不写 → 收敛。

### 零 fork 节流

节流用 `$SECONDS`（mksh 内建），不 fork `date`。省的是 CPU 唤醒，不显眼但攒起来是真金白银。

### 自愈

logcat 管道哪天被踢了怎么办？外层再套一个 while，管道死了就兜底检查一次、睡 60 秒重启。事件驱动负责省电，轮询负责兜底，两者不冲突。

## 后记

其实这东西不需要写博客。两个 while 循环，加起来不到 80 行。

但那天晚上写完的时候挺开心的。深夜改自己手机上的设置，跟自己造的一个小系统较劲，最后看着它跑起来、安静下来——这种事是值得记一笔的。

再过几年看到这篇，我可能已经忘了 `commit_sys_config_file` 是什么了。但应该还能想起这个晚上。

---

*代码在 KernelSU 模块 `nannan_doze` 里，`service.sh` 一个文件就是全部逻辑。*