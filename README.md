# Deadlight Comm

**Deadlight Comm** is a modular, edge-native communication framework for people who want more than just email. It’s an inbox that can receive anything—from email, RSS, contact forms, to system alerts—and lets you reply in Markdown, automate flows, and own your data. Built around core values of data ownership, transparency, and user empowerment.

## ✨ Vision

A personal communication operating system—running at the edge, written in modular components, and designed to evolve with the user.

- Edge-native: deployable on Cloudflare, Deno, or other edge compute platforms.
- Markdown-first: every message is treated like a readable, portable blog post.
- Modular: components for parsing, fetching, storing, and rendering can be swapped or extended.
- Privacy-focused: users retain full data ownership and can export at any time.

## 🧱 Architecture Overview

Deadlight Comm is composed of:

- **Proxy Layer** – C-based server that speaks raw IMAP/SMTP and delivers JSON.
- **Worker Layer** – Cloudflare Worker handling auth, parsing, routing, and UI orchestration.
- **Parser Module** – Wasm-powered message parser with support for plain text, HTML, and attachments.
- **UI Layer** – Inbox-as-blog frontend for reading and replying in Markdown.
- **Storage Layer** – D1 for metadata, R2 (optional) for attachments.
- **Plugin Hooks** – Add new capabilities like AI summaries, spam filters, or SMS routing.

> See `docs/` and module READMEs for deeper dives once project is scaffolded.

## 🚀 Getting Started

Clone this repo and get the basic environment up and running.

```bash
git clone https://github.com/deadlight-labs/deadlight-comm.git
cd deadlight-comm
make setup
make dev
```

Modules are contained in their own directories and initialized via Makefile targets.
## 🎯 Philosophy

Deadlight Comm is built around:
- Modularity – Each component is replaceable.
- Transparency – All actions are observable, debuggable, and documented.
- Data Sovereignty – The user owns their inbox and can walk away with their data at any time.
- Composability – Future plugins and new protocols can be easily added.


## 📜 License
MIT — Use it, fork it, ship it.
