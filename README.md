# Snorfeld - A Reluctant AI Writing Companion

## Description

Snorfeld is a desktop writing assistant that provides real-time, AI-powered feedback on your writing. Built with Godot Engine, Snorfeld connects to local large language models (via Ollama) to analyze your text and offer suggestions for grammar, style, and structure improvements.

Unlike gentle writing tools that sugarcoat feedback, Snorfeld gives you direct, actionable corrections — helping you improve your writing through honest, AI-driven analysis.

## Functionality

### Core Features

**Real-Time Paragraph Analysis**
- Analyzes each paragraph as you write or navigate through your document
- Displays color-coded diffs showing suggested changes
- Click on any suggestion to instantly apply it to your text

**Three Analysis Modes**

| Mode | Purpose | 
|------|---------|
| **Grammar** | Fixes spelling, grammar, and punctuation errors |
| **Style** | Improves readability, flow, and word choice |
| **Structure** | Enhances plot, pacing, and narrative flow |

### How It Works

1. **Open a Folder** → Browse and select your project directory
2. **Select a File** → Click any text file to open it in the editor
3. **Navigate Paragraphs** → Move your cursor to any line to see analysis
4. **Review Suggestions** → View diffs and explanations in the side panel
5. **Apply Changes** → Click on highlighted text to accept suggestions

### Supported File Types

All common text formats: `.txt`, `.md`, `.yml`, `.yaml`, `.json`, `.csv`, `.html`, `.htm`, `.xml`, `.js`, `.ts`, `.py`, `.rb`, `.go`, `.rs`, `.java`, `.c`, `.cpp`, `.h`, `.hpp`, `.sh`, `.sql`, `.log`, `.cfg`, `.ini`, `.toml`, `.tex`, `.rst`

### AI Integration

- **Local LLM Support**: Connects to Ollama for privacy-focused, offline-capable AI analysis
- **Configurable Models**: Use any Ollama-compatible model (default: `qwen3.5:9b`)
- **Customizable Settings**: Adjust temperature, max tokens, and API endpoints

### Settings

Configure your LLM connection:
- **Endpoint**: Ollama API URL (default: `http://localhost:11434/api/generate`)
- **Model**: Choose your preferred model
- **Temperature**: Control creativity (lower = more deterministic)
- **Max Tokens**: Limit response length

### Caching

- Analysis results are cached locally in the `.snorfeld` folder
- Each paragraph is analyzed once and stored for future sessions
- Cached suggestions appear instantly when reopening files

### Keyboard-Friendly

- Navigate with cursor keys
- Suggestions update automatically as you move between paragraphs
- Manual edits preserve your original intent while still showing new suggestions

---

*Snorfeld: Because good writing requires honest feedback.*
