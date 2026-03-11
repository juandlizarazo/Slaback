# Slaback

A native macOS app for browsing Slack workspace exports offline. Everything stays on your Mac.

## What it does

Slaback reads the JSON files from a standard Slack export and presents them in a familiar channel-based interface — sidebar, message list, threads, and search — without needing a browser or sending anything over the network.

## Features

- **Channel sidebar** with message and file counts
- **Message rendering** with Slack formatting (bold, italic, strikethrough, code blocks, @mentions, #channel references, links)
- **Thread panel** for viewing threaded conversations
- **Full-text search** across all channels and replies
- **File and image attachments** displayed inline, with a lightbox for images
- **Bundled download script** to fetch attached files before Slack's URLs expire
- **Dark theme** matching Slack's color scheme

## How to use

### 1. Export your Slack workspace

Go to your Slack workspace settings, then **Import/Export Data**, and choose **Export**. Slack will email you a download link when the `.zip` file is ready.

### 2. Unzip the export

Extract the `.zip`. You'll get a folder structured like this:

```
My Slack Export/
├── channels.json
├── users.json
├── general/
│   ├── 2024-01-15.json
│   ├── 2024-01-16.json
│   └── ...
├── random/
│   └── ...
└── ...
```

### 3. Download attached files (optional)

Slack exports contain message text but **not** the actual files and images people shared — only temporary URLs that expire. To save them locally, run the bundled download script from Terminal:

```bash
bash slack-download-files.sh /path/to/My\ Slack\ Export
```

You can copy or save this script from within the app (look for **File Download Script** in the sidebar or on the welcome screen). Downloaded files are saved to a `_files/` subfolder and Slaback picks them up automatically.

### 4. Open the folder in Slaback

Launch the app and click **Open Slack Export Folder**, then select your unzipped export directory. Slaback loads all channels, messages, users, and local files from that folder.

## Building

Open `Slaback.xcodeproj` in Xcode and build for macOS. No external dependencies.

## Privacy

Slaback is entirely offline. It reads files from disk and never makes network requests. Your workspace data stays on your machine.
