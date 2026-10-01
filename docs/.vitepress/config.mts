import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'zh-CN',
  title: 'Snowveil',
  description: '基于 Nix Flakes 的配置框架',
  cleanUrls: true,
  lastUpdated: {
    text: '最后更新于',
    formatOptions: {
      dateStyle: 'short',
      timeStyle: 'medium',
    },
  },
  themeConfig: {
    outline: { level: [2, 3], label: '本页目录' },
    nav: [
      { text: '开始', link: '/guide/introduction' },
      { text: '指南', link: '/guide/hosts' },
      { text: '概念', link: '/concepts/philosophy' },
      { text: '迁移', link: '/migration/from-plain-flake' },
      { text: '参考', link: '/reference/core' },
      { text: '进阶', link: '/advanced/debugging' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: '🚀 开始',
          items: [
            { text: '什么是 Snowveil', link: '/guide/introduction' },
            { text: '快速开始（5 分钟）', link: '/guide/getting-started' },
            { text: '项目结构', link: '/guide/directory-structure' },
            { text: '示例项目', link: '/guide/example-repository' },
          ],
        },
        {
          text: '📖 指南',
          items: [
            { text: 'Hosts（主机）', link: '/guide/hosts' },
            { text: 'Users（用户）', link: '/guide/users' },
            { text: 'Home Manager 整合', link: '/guide/home-manager' },
            { text: 'Modules（模块）', link: '/guide/modules' },
            { text: '模块依赖与排序', link: '/guide/module-dependencies' },
            { text: 'Roles（角色）', link: '/guide/roles' },
            { text: 'Profiles（配置集）', link: '/guide/profiles' },
            { text: 'Packages（软件包）', link: '/guide/packages' },
            { text: 'Overlays 与 Patches', link: '/guide/overlays-patches' },
            { text: 'Secrets（密钥管理）', link: '/guide/sops' },
            { text: '自定义 Outputs 扩展', link: '/guide/extensions' },
          ],
        },
      ],
      '/concepts/': [
        {
          text: '🧠 概念与原理',
          items: [
            { text: '核心理念与对比', link: '/concepts/philosophy' },
            { text: '目录自动发现机制', link: '/concepts/discovery' },
            { text: '模块依赖系统设计', link: '/concepts/module-dependency-system' },
            { text: '元数据设计 (meta.nix)', link: '/concepts/metadata' },
            { text: '架构与求值模型', link: '/concepts/architecture' },
          ],
        },
      ],
      '/migration/': [
        {
          text: '🔄 迁移指南',
          items: [
            { text: '普通 Flake → Snowveil', link: '/migration/from-plain-flake' },
            { text: 'snowfall → Snowveil', link: '/migration/from-snowfall' },
            { text: 'flake-parts → Snowveil', link: '/migration/from-flake-parts' },
            { text: 'nixos-unified → Snowveil', link: '/migration/from-nixos-unified' },
          ],
        },
      ],
      '/reference/': [
        {
          text: '📚 参考规范',
          items: [
            { text: 'Core API', link: '/reference/core' },
            { text: 'meta.nix 元数据规范', link: '/reference/meta' },
            { text: 'Discovery 发现规范', link: '/reference/discovery' },
            { text: 'Generated Outputs 映射', link: '/reference/generated-outputs' },
            { text: '版本策略', link: '/reference/versioning' },
          ],
        },
      ],
      '/advanced/': [
        {
          text: '🛠 进阶开发',
          items: [
            { text: '调试与问题排查', link: '/advanced/debugging' },
            { text: '性能调优', link: '/advanced/performance' },
            { text: '自定义 Outputs 进阶', link: '/advanced/custom-outputs' },
            { text: '外部模块注册表', link: '/advanced/registries' },
            { text: '补丁应用助手 (Patches)', link: '/advanced/patches' },
          ],
        },
      ],
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/SnowveilOrg/Snowveil' },
    ],
    editLink: {
      pattern: 'https://github.com/SnowveilOrg/Snowveil/edit/main/docs/:path',
      text: '编辑此页',
    },
    search: { provider: 'local' },
    sidebarMenuLabel: '菜单',
    returnToTopLabel: '返回顶部',
    docFooter: { prev: '上一页', next: '下一页' },
    footer: {
      message: 'MIT 许可发布',
      copyright: 'Copyright © 2026 RhenCloud',
    },
  },
})
