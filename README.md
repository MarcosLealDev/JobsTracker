# JobsTracker

A macOS app that analyzes job postings using a local LLM. Paste a job description and the app extracts the company info, job title, and a checklist of technical skills so you can track what you know and what you need to learn.

## Requirements

- macOS 26.2+
- Xcode 26+
- [Ollama](https://ollama.com) running locally with the `llama3.1` model

## Setup

1. Install and start Ollama:
   ```bash
   brew install ollama
   ollama serve
   ```

2. Pull the required model:
   ```bash
   ollama pull llama3.1:latest
   ```

3. Open and run the project:
   ```bash
   open JobsTracker.xcodeproj
   ```

4. In Xcode, ensure the **Outgoing Connections (Client)** capability is enabled under Signing & Capabilities for the JobsTracker target.

## Usage

1. Click **+** to add a new job entry
2. Paste a job description and click **Analyze with AI**
3. The app extracts company details and technical skills
4. Check off skills you already know — get a gold star when you know them all
5. Edit any field directly, or re-analyze after updating the description
