# LJRNN 的笔记

Hugo + PaperMod 搭建的个人博客，构建与发布由 GitHub Actions 自动完成。

线上地址：<https://ljrnn.github.io/blog/>

## 写一篇新文章

```bash
hugo new content posts/我的文章.md
```

生成的文件里 `draft: true` 表示草稿，不会发布。写好把 `draft` 改成 `false`，然后：

```bash
git add -A
git commit -m "post: 我的文章"
git push
```

约 40 秒后线上生效。

## 只用网页也能发

1. 打开 <https://github.com/LJRNN/blog/new/main/content/posts>
2. 文件名填 `我的文章.md`
3. 粘贴上面的模板，写内容
4. 页面底部选 **Create a new branch for this commit and start a pull request**，或者直接 commit 到 main（推荐直接 commit，自动发布）

## 本地预览（可选）

装了 Hugo 的话：

```bash
hugo server -D
# 打开 http://localhost:1313
```

`-D` 连草稿一起显示。没装 Hugo 也不影响发文章，Actions 那边会构建。

## 目录

```
hugo.toml                    站点配置（标题、菜单、主题参数）
content/posts/               文章，一篇一个 .md
content/about.md             关于页
content/archives.md          归档页（用 PaperMod 的 archives 布局）
content/search.md            搜索页
static/                      favicon 等静态文件
themes/PaperMod/             主题，直接放进仓库，不需要 submodule
.github/workflows/hugo.yml   自动构建发布
```

## 常用改动

**改站点名 / 副标题**：`hugo.toml` 里的 `title` 和 `[params.homeInfoParams]`。

**改菜单**：`hugo.toml` 里的 `[[menus.main]]`。

**换配色**：PaperMod 没有内置配色，改 `assets/css/extended/custom.css`（新建即可，会自动加载）：

```css
:root {
  --primary: #2f6bff;
}
```

**加评论**：PaperMod 支持 giscus，在 `hugo.toml` 的 `[params]` 里加：

```toml
[params.giscus]
  repo = "LJRNN/blog"
  repoId = "..."
  category = "Announcements"
  categoryId = "..."
  mapping = "pathname"
```

## 换域名之后

改 `hugo.toml` 的 `baseURL`，再在仓库 Settings → Pages → Custom domain 里填域名。Actions 里的 `--baseURL` 会自动用 Pages 给的地址覆盖，所以主要改 `Custom domain` 即可。

## 许可

文章版权归作者，代码片段随意取用。主题 [PaperMod](https://github.com/adityatelange/hugo-PaperMod) 为 MIT。
