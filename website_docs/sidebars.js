// @ts-check

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.

 @type {import('@docusaurus/plugin-content-docs').SidebarsConfig}
 */
const sidebars = {
  tutorialSidebar: [
    {
      type: 'category',
      label: '🚀 Memulai',
      collapsed: false,
      items: ['intro', 'quick-start'],
    },
    {
      type: 'category',
      label: '📖 Panduan Pengguna',
      items: ['features', 'user-guide', 'gallery'],
    },
    {
      type: 'category',
      label: '⚙️ Teknis & Konfigurasi',
      items: ['deployment', 'configuration', 'security'],
    },
    {
      type: 'category',
      label: '💻 Arsitektur & Developer',
      items: ['architecture', 'api-reference', 'from-scratch', 'contributing', 'changelog'],
    },
  ],
};

export default sidebars;
