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

- **Proxy Layer** – C-based server that speaks raw IMAP/SMTP and delivers JSON (currently prototyped with GNU Mailutils and `curl`).
- **Worker Layer** – Cloudflare Worker handling auth, parsing, routing, and UI orchestration (planned for future integration).
- **Parser Module** – Wasm-powered message parser with support for plain text, HTML, and attachments (currently using GNU Awk for local parsing).
- **UI Layer** – Inbox-as-blog frontend for reading and replying in Markdown (planned, to integrate with `blog.deadlight`).
- **Storage Layer** – D1 for metadata, R2 (optional) for attachments (currently JSON files locally, preparing for D1 simulation with SQLite).
- **Plugin Hooks** – Add new capabilities like AI summaries, spam filters, or SMS routing (future goal).

> See `docs/` and module READMEs for deeper dives once project is scaffolded.

## 🚀 Current Status (Updated August 2025)

Deadlight Comm is in active development with a functional local prototype for email handling, aligning with the "catch-up" model (fetching and sending emails on-demand when the user logs in). Key achievements:

- **Email Fetching**: Successfully retrieves emails from Gmail via IMAP using GNU Mailutils (`movemail`).
- **Email Parsing**: Processes raw emails into JSON format with GNU Awk, decoding Base64 `text/plain` content into readable text.
- **Email Sending**: Sends pending emails from an outbox folder using `curl` via Gmail’s SMTP server.
- **Storage**: Saves parsed emails as JSON files locally, with plans for SQLite to simulate D1 integration.
- **Next Steps**: Integrate with `lib.deadlight`’s Markdown processor for content formatting, transition to SQLite storage, and prototype integration with `blog.deadlight` for private inbox display.

This prototype serves as a foundation for the broader vision of an edge-native system, with local components preparing for deployment to Cloudflare Workers.

## 🛠️ Getting Started

Clone this repo and get the basic environment up and running.

```bash
git clone https://github.com/deadlight-labs/deadlight-comm.git
cd deadlight-comm
make setup
make dev
```
Modules are contained in their own directories and initialized via Makefile targets. For the current prototype, follow these manual steps:

## Prerequisites
- GNU Mailutils (sudo apt install mailutils) for IMAP/SMTP handling.
- GNU Awk (sudo apt install gawk) for email parsing.
- curl (sudo apt install curl) for sending emails.
- Linux or WSL environment for local development.

## Setup and Run Prototype

1. Configure Gmail Credentials:
2. Generate a Gmail App Password for third-party access.
3. Save it securely in ~/.deadlight_credentials with chmod 600 ~/.deadlight_credentials.
4. Update Scripts:
    -Save catchup.sh and parse_email.awk scripts (provided in project or documentation).
5. Ensure catchup.sh reads the password from ~/.deadlight_credentials.
6. Run Catch-Up Workflow:
```
bash
./catchup.sh
This fetches emails, parses them to JSON, stores them in ~/comm.deadlight/emails/, and sends pending emails from ~/comm.deadlight/outbox/.
```
## 🎯 Philosophy

Deadlight Comm is built around:

Modularity – Each component is replaceable.
Transparency – All actions are observable, debuggable, and documented.
Data Sovereignty – The user owns their inbox and can walk away with their data at any time.
Composability – Future plugins and new protocols can be easily added.

## 📜 License
MIT — Use it, fork it, ship it.
