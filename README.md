<p align="center">
  <img src="AppIcon-1024.png" alt="Nest app icon" width="160" height="160">
</p>

<h1 align="center">Nest</h1>

<p align="center">
  <strong>Your Finder-native AI companion for macOS.</strong><br>
  <a href="https://youtu.be/depebDj8i74">📺 Watch the Demo Video</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/AI-Bring_Your_Own-0088cc?style=for-the-badge&logo=openai&logoColor=white" alt="Bring Your Own AI">
</p>

<hr>

### 🧠 What is Nest?

**Nest is a native macOS AI agent that lives directly inside Finder.** 

Instead of copying and pasting files into a web browser, just select files right in Finder, tell Nest what you want, and let it work. Whether you need to inspect code, transform documents, organize chaotic folders, or act on media, Nest understands your current selection using natural language.

It docks elegantly beneath the active Finder window, speaks to your chosen AI provider, and translates your requests into safe, useful local file actions.

### ✨ Features

- **🎯 Finder-Native Experience:** Docks perfectly with your active window. No context switching.
- **🗣️ Natural Language Commands:** Talk to your files in plain English.
- **🔌 Bring Your Own AI:** Plug in your API keys. Supports **Gemini, OpenRouter, OpenAI-compatible APIs**, and even **Ollama** for 100% offline local privacy.
- **⚡ Instant Shortcuts:** Pre-built instant actions for common, repetitive file operations.
- **🛡️ Safe by Design:** Harmless commands run automatically. Risky or destructive commands are presented as a preview for your explicit approval.
- **📊 Live Progress:** Real-time in-bar progress and result display.
- **📜 Activity Log:** Keep track of recent prompts, generated commands, and terminal outputs.
- **🛠️ Extensible:** Supports optional CLI tools like `ImageMagick`, `FFmpeg`, `Pandoc`, and `Poppler` for advanced transformations.

---

## 💡 Use Cases

Looking for ideas? Here are some example commands to try directly from Finder:

### 🎬 Video & Audio
For quick conversions you can just type a format name (e.g., “mp4”, “wav”). Some advanced operations use optional extra tools that Nest can install automatically via Homebrew (with your confirmation).
- `Convert to mp4`
- `mp4`
- `Convert to mp4, 1080p, 30fps, 1000kbit/s`
- `Make animated gif from this mp4, 600 pixels wide, 12fps`
- `what bitrate is this video?`
- `Trim this 16:9 video to be 16:10`

### 🖼️ Images
Short prompts work: say just the target format (e.g., “jpg”, “png”). Some image operations can use optional tools like ImageMagick, installed via Homebrew on request.
- `Make a jpg`
- `jpg`
- `Rotate this image right by 90 degrees`
- `Batch resize all images in this folder to 1024 pixels wide`
- `resize this to 1080 px tall`
- `is this file with a .jpg extension actually a PNG?`
- `Make a 3x3 grid of images out of these`
- `Put a 10px border around this image`
- `Crop this image by 50 pixels on each side`
- `Overlay this image with "Nest" in bold white letters`

### 🧮 Calculations
Nest answers maths questions using the built‑in `bc` calculator on your Mac. We translate your prompt into an exact expression and evaluate it locally with high precision—so you get deterministic results without any AI “best guesses”.
- `5 foot 9 in cm?`
- `1 day in seconds?`
- `15% of $85.99?`
- `Convert 42 USD to EUR`
- `What's the square root of 1764?`

### 🗄️ Zip Archives
Create and inspect archives.
- `Zip these up`
- `zip`
- `What files are inside this zip?`
- `put in screenshots folder, zip em up!`

### 📝 Text
Quick text utilities and editing.
- `open in Text Mate`
- `Make a new readme.txt`
- `word count?`

### 📂 File Organization
Sort and tidy folders in just a few words.
- `tidy up this folder`
- `organize by date`

### 📄 Document Conversion
Convert between document formats. Nest can use Pandoc for best‑in‑class conversions, and can install it automatically via Homebrew (with your confirmation).
- `Convert this docx to html`
- `Convert this DOCX to Markdown`
- `Convert this Markdown to HTML`
- `Convert this DOCX to EPUB`

### 📕 PDFs
Advanced PDF tools use optional extra utilities such as QPDF, Ghostscript and Poppler that Nest can install automatically via Homebrew (with confirmation).
- `author of this pdf?`
- `Optimise this PDF`
- `Extract the text from this PDF`
- `Save just page 2 of this PDF to a separate file`
- `Rotate page 2 of this PDF by 90 degrees clockwise`
- `Merge these PDFs`
- `Remove password from this PDF`
- `Add a password to this PDF`
- `Split this PDF into separate pages`

### 🔍 File Metadata
Inspect file types, sources and permissions.
- `What type of file is this?`
- `Where did I download this file from?`
- `Why is this file greyed out in Finder?`

### 🌐 Web
- `Download this file here: <url>`

### 💻 Code & Version Control
- `total lines of JavaScript?`
- `Commit and push everything`
- `switch to dev branch`

### ⚙️ System & Utilities
- `Print this out`
- `Keep my Mac awake for the next hour`
- `Toggle dark mode`
- `Make invisible files visible`
- `What processor does this Mac have?`
- `How much RAM do I have?`

### 🌤️ Weather
- `What's the weather in Tokyo?`

### 🧩 Other
- `pwd`
- `Send this using the Messages app to "friend@example.com"`

---

## 📸 See it in Action

<p align="center">
  <img src="pic/1.png" width="48%">
  <img src="pic/2.png" width="48%">
  <br><br>
  <img src="pic/3.png" width="48%">
  <img src="pic/4.png" width="48%">
  <br><br>
  <img src="pic/5.png" width="48%">
</p>

---

## 🚀 Getting Started

### Download
Grab the latest `.dmg` from the GitHub Releases page:

👉 **[Download Nest Now](https://github.com/HyperOrb/Nest/releases/latest)**

1. Open the `.dmg` and drag **Nest** into your `Applications` folder.
2. Launch Nest. *(If macOS warns about an unidentified developer, right-click Nest and select **Open**).*

### Permissions
Nest acts as your hands and eyes in the file system. It requires macOS **Accessibility** and **Automation** permissions to follow Finder windows and understand selected files. macOS will prompt you for these on the first run.

---

## ⚙️ Configuration

### AI Providers
Nest is completely BYOK (Bring Your Key). API keys are stored securely and locally on your machine at:
```bash
~/.finder_ai_config.json
```

### Optional Tools
Nest can leverage powerful open-source tools if you have them installed. It will never install them automatically without your permission.
- **ImageMagick:** For advanced image manipulation.
- **FFmpeg/FFprobe:** For video/audio conversion and inspection.
- **Pandoc:** For document conversion (Markdown, Word, PDF).
- **Poppler / QPDF:** For advanced PDF wizardry.

---

<p align="center">
  <i>Built with Swift, AppKit, and SwiftUI.</i><br>
  <b>Designed for builders who live in Finder.</b>
</p>
