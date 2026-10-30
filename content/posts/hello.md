---
title: "开张"
date: 2026-10-30
draft: false
slug: "hello"
tags: ["随笔"]
categories: ["记录"]
description: "换了三次地方，这次把它钉在 GitHub 上。"
ShowToc: false
---

写过一些东西散在各处：Issue 里、聊天记录里、代码注释里。事后想找一句话，翻半天。

所以干脆开一个固定地址，把值得留下的挪过来。

## 为什么是 Hugo

一句话：我不想两年后回来发现跑不起来。

Hexo 依赖一条长长的 npm 链，Node 大版本一跳，插件就有一半报错。Hugo 是一个静态二进制，没有运行时依赖，五年后还是那个命令。

代价是 Go 模板语法有点反直觉，但站点配置一次就基本不用碰了。

## 为什么是 PaperMod

试过 Stack 和 Blowfish，都好看，但功能堆得多。PaperMod 只做三件事：列文章、读文章、搜文章，剩下什么都不管。星数 13k 排 Hugo 主题第一，说明大多数人最后都落到这个取舍上。

## 怎么发文章

```bash
hugo new content posts/我的文章.md
# 写完，存进 content/posts/，push
git add -A && git commit -m "post: xxx" && git push
```

剩下的 GitHub Actions 会做：拉代码、装 Hugo、构建、发布到 Pages。本地不用装任何东西。

---

后面会陆续把之前的工程记录搬过来。第一篇写的是最近那个把 WorkBuddy 额度包成 OpenAI 接口的网关。
