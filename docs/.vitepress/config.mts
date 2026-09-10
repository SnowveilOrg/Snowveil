import { defineConfig } from 'vitepress'

export default defineConfig({
  lang: 'zh-CN',
  title: 'Snowveil',
  description: '基于 Nix Flakes 的配置框架',
  cleanUrls: true,
  lastUpdated: '最后更新于',
  themeConfig: {
    outline: { level: [2, 3], label: '本页目录' },
    nav: [
      { text: '开始', link: '/guide/introduction' },
      { text: '指南', link: '/guide/hosts' },
      { text: '概念', link: '/concepts/philosophy' },
      { text: '迁移', link: '/migration/from-plain-flake' },
      { text: '参考', link: '/reference/meta' },
      { text: '进阶', link: '/advanced/debugging' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: '🚀 开始',
          items: [
            { text: '什么是 Snowveil', link: '/guide/introduction' },
            { text: '为什么使用 Snowveil', link: '/concepts/philosophy' },
            { text: '快速开始', link: '/guide/getting-started' },
            { text: '项目结构', link: '/guide/directory-structure' },
            { text: '示例项目', link: '/guide/example-repository' },
          ],
        },
        {
          text: '📖 指南',
          items: [
            { text: 'Hosts', link: '/guide/hosts' },
            { text: 'Users', link: '/guide/users' },
            { text: 'Home Manager', link: '/guide/home-manager' },
            { text: 'Modules', link: '/guide/modules' },
            { text: 'Roles', link: '/guide/roles' },
            { text: 'Profiles', link: '/guide/profiles' },,
            { text: 'Packages', link: '/guide/packages' },
            { text: 'Overlays', link: '/guide/overlays-patches' },
            { text: 'Secrets', link: '/guide/sops' },
            { text: '自定义 Outputs', link: '/guide/extensions' },
          ],
        },
      ],
      '/concepts/': [
        {
          text: '🧠 概念',
          items: [
            { text: '核心理念', link: '/concepts/philosophy' },
            { text: 'Discovery', link: '/concepts/discovery' },
            { text: 'Module Graph', link: '/guide/module-dependencies' },
            { text: 'Metadata', link: '/concepts/metadata' },
            { text: 'Evaluation Model', link: '/concepts/architecture' },
          ],
        },
      ],
      '/migration/': [
        {
          text: '🔄 迁移',
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
          text: '📚 Reference',
          items: [
            { text: 'meta.nix', link: '/reference/meta' },
            { text: 'Discovery Specification', link: '/reference/discovery' },
            { text: 'Core API', link: '/api/core' },
            { text: 'Outputs', link: '/reference/generated-outputs' },
            { text: '版本策略', link: '/reference/versioning' },
          ],
        },
      ],
      '/api/': [
        {
          text: '📚 Reference',
          items: [
            { text: 'meta.nix', link: '/reference/meta' },
            { text: 'Discovery Specification', link: '/reference/discovery' },
            { text: 'Core API', link: '/api/core' },
            { text: 'Outputs', link: '/reference/generated-outputs' },
          ],
        },
      ],
      '/advanced/': [
        {
          text: '🛠 Advanced',
          items: [
            { text: 'Debugging', link: '/advanced/debugging' },
            { text: 'Performance', link: '/advanced/performance' },
            { text: 'Extending Snowveil', link: '/advanced/custom-outputs' },
            { text: 'Internals', link: '/concepts/architecture' },
            { text: '外部模块注册表', link: '/advanced/registries' },
            { text: 'Patch helper', link: '/advanced/patches' },
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
