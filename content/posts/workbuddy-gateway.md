---
title: "把订阅额度包成 OpenAI 接口：一个跑在手机上的网关"
date: 2026-10-30
draft: false
slug: "workbuddy-gateway"
tags: ["Go", "Android", "网关", "NDK"]
categories: ["工具"]
description: "为什么不用官方客户端、账号池怎么轮、安卓上跑 Go 服务要注意什么。"
ShowToc: true
TocOpen: false
---

手上有几个 WorkBuddy 账号，额度分散，官方客户端一次只能用一个。想在任何支持 OpenAI 协议的编辑器里直接用，就得有人把协议翻一遍、把账号轮起来。

这东西本来跑在电脑上，但我不想为了用个接口天天开着电脑。于是有了这个跑在手机上的版本。

## 整体形状

```
客户端(任意 OpenAI 兼容)  ──►  手机上的 Go 网关  ──►  WorkBuddy 上游
                                    │
                            账号池 / 冷却 / 会话粘性
```

网关本体是一个 Go 二进制，监听 `127.0.0.1:7863`，对外暴露 `/v1/chat/completions`、`/v1/models`。客户端填上 Base URL 和一个自生成的 API Key 就能用。

有两种装法：

| 形态 | 依赖 | 适合 |
|---|---|---|
| APK | 普通安卓，无需 root | 大多数情况 |
| KernelSU 模块 | 需要 root | 想开机自启、不要常驻通知 |

## 三个真正花时间的点

### 1. 账号池不能只是轮询

最初是简单的轮询，结果很糟：上一个请求刚用完账号 A，下一个请求换到 B，B 又不认识刚才的对话。多轮对话直接断片。

改成了**会话粘性**：拿 `conversation_id` 的指纹做键，绑到具体账号上，TTL 30 分钟。同一段对话永远落在同一个账号，换话题才可能漂移。

```go
// 伪代码
func (s *Sticky) Pick(fingerprint string) (*Account, bool) {
    if a, ok := s.get(fingerprint); ok {
        return a, true
    }
    a := s.pool.Next()
    s.set(fingerprint, a, 30*time.Minute)
    return a, false
}
```

### 2. 冷却要分错误码

所有错误都退避 60 秒是偷懒。实际上：

- **402**（额度耗尽）→ 直接压到次日 04:00，中间不用再试
- **429**（限流）→ 指数退避，从 10 秒起翻倍，封顶 10 分钟
- **404**（模型不存在）→ 固定 60 秒，通常是上游模型列表变了

按错误码分策略之后，无效重试少了一大截，账号也不会因为一次限流被误伤半天。

### 3. 冻结诊断

手机上跑后台服务最怕的是「看着在跑，其实早就僵了」。进程活着，但 goroutine 卡住，请求进来没响应。

加了个 30 秒心跳：服务每分钟打一次点，写进 `beat`、`bootCount`、`freezeCount`。超过 90 秒没打点就判定冻结，界面上直接红字告警。日志里能看出是第几次冻结、上次运行了多久。

这个功能上线之后，才第一次看清问题到底是「网络慢」还是「真的死了」。

## 安卓上跑 Go 服务

几个绕不开的坑：

**必须用 CGO。** 纯 Go 编译出来是静态链接的，DNS 解析走自己的实现，在安卓上会因为缺 `resolv.conf` 直接失败。加上 `CGO_ENABLED=1`，用 NDK 的 clang 编译，走 bionic 的解析器就正常了。

```bash
GOOS=android GOARCH=arm64 CGO_ENABLED=1 \
  CC=$NDK/aarch64-linux-android26-clang \
  go build -trimpath -ldflags "-s -w" -o libwb2api.so ./cmd/server
```

产物后缀虽然叫 `.so`，其实是可执行文件，放在 `jniLibs/` 里由 App 直接 `exec`。这样能绕开 `data` 分区不可执行的限制。

**省电要看的是唤醒锁，不是 CPU。** 早期版本持有 `PARTIAL_WAKE_LOCK`，后台跑一晚上掉 20% 电。去掉之后改成前台服务 + 系统调度，空闲时 CPU 占用接近 0，掉电回到 3% 以内。

**32 位机器还很多。** `GOARM=7` 单独编一份，两份二进制按 ABI 分目录，安装时按当前架构只保留一份。

## 多模态是另一个故事

文本转发很直接，视频和音频就麻烦了 —— 上游接口不认 `video_url`，也不认 `input_audio`，直接过滤掉。

最后的做法是本地预处理：

- **视频**：事件引导抽帧（场景切换处多抽几张），转成 `image_url` 数组塞进消息
- **音频**：抽音轨转 16kHz WAV，本地跑 TFLite 做声音事件识别，同时走上游 ASR 转文字

抽帧数量和压缩质量做成无极调节的滑杆，因为「抽 4 帧」和「抽 16 帧」在不同视频上差别很大，固定值总有一头不合适。

## 一些数字

arm64、两个账号、空闲状态：

| 指标 | 值 |
|---|---|
| RSS | 26–34 MB |
| 稳态 CPU | ≈ 0（只有 30 秒心跳和签到定时器） |
| 冷启动到可用 | 约 1.2 秒 |
| APK 体积（轻量版） | 12 MB |
| APK 体积（带音频模型） | 170 MB |

那个 170 MB 主要花在 PANNs CNN14（155 MB）上。轻量版砍掉模型，声音事件识别就没了，语音转写照常走上游。

## 最后

项目在 [GitHub](https://github.com/LJRNN/WorkBuddyGateway)。

一句提醒：这类工具本质是拿非官方通道接官方额度，条款上站不住脚。自己用可以，别拿去分发或商用。
