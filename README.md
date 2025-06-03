<img src="/source/Syncerra_Logo.png" width="150px" alt="Syncerra Logo">
# ⚡ Syncerra

A blazing-fast local-to-system sync utility powered by Bash and JSON metadata. Designed for developers who care about precision, clarity, and automation.

> 🛠 Created by **Artur Flis** | Version `0.1.0`

---

## 🚀 What is Syncerra?

Syncerra is a smart shell script that helps you **track, inspect, and sync** local file or folder mirrors from your system (like `/etc`, system dotfiles, or app configs) into a clean local project structure — all defined via a `files.json` mapping.

Imagine syncing vital system configurations back into your local repo with a single command — without the headaches of messy manual diffs or bloated backup scripts.

---

## 🧰 Features

* 🔍 **Diff & Inspect**: Visually inspect differences between local and system files or folders.
* ➕ **Add Mappings**: Define new mappings interactively with flexible file/folder creation.
* 📂 **List & Remove**: Easily list or prune mappings with clean fzf-based UIs.
* 🔁 **Sync with Confidence**: Safely mirror system state into your repo with a single prompt.
* 💡 **Fuzzy UI + Precise Diffs**: Combine interactive selection (`fzf`) with full `diff -ur` precision.

---

## 📦 Requirements

* `bash`
* [`jq`](https://stedolan.github.io/jq/)
* [`fzf`](https://github.com/junegunn/fzf) *(for interactive commands)*

---

## 🛠️ Usage

```bash
./syncerra.sh [OPTIONS]
```

### Common Options

| Option                        | Description                                               |
| ----------------------------- | --------------------------------------------------------- |
| `--add <path>`                | Add a new file/folder mapping to sync from `<path>`.      |
| `--inspect`                   | Fuzzy interactive mismatch browser (fast, readable diff). |
| `--inspect-precise` or `--ip` | Full detailed diff output (`diff -ur`).                   |
| `--list`                      | View current file mappings in `files.json`.               |
| `--remove`                    | Remove a mapping entry via interactive fuzzy search.      |
| `-v`, `--version`             | Show script version.                                      |
| `-h`, `--help`                | Show help menu.                                           |
| *(no option)*                 | Perform default sync check and offer to sync mismatches.  |

---

## 🧪 Examples

### 🔧 Add a New Mapping

```bash
./syncerra.sh --add /etc/nginx/
```

You'll be prompted to give this mapping a key and specify a local target (e.g., `nginx-config`), which will be created under your script directory.

---

### 🧠 Inspect Differences

```bash
./syncerra.sh --inspect
```

Fuzzy-select mappings with mismatches and view clean, colored summaries of what’s off.

Or go deeper:

```bash
./syncerra.sh --ip
```

View full `diff -ur` output, line by line.

---

### 🧹 Clean Mappings

```bash
./syncerra.sh --remove
```

Interactively prune outdated or unused mappings from your JSON config.

---

## 🗃️ `files.json` Format (auto-managed)

Mappings are stored as simple JSON objects like this:

```json
{
  "nginx": {
    "destination": "/etc/nginx",
    "filename": "/your/local/project/nginx-config",
    "type": "folder"
  }
}
```

You don’t need to touch this manually — Syncerra manages it for you.

---

## 💡 Design Philosophy

* **Local-first**: Your local repo is canonical; the system mirrors it.
* **Dry-run by default**: No silent overwrites. You always approve syncs.
* **Minimal deps, maximal clarity**: One file. Two dependencies. Full control.

## 🧠 Tip

Use Syncerra to version-control your dotfiles, NGINX confs, `/etc` setups, or any scattered system config you want safely mirrored in one place.

```bash
./syncerra.sh
```

That’s all. You’ll know if anything’s out of sync.

---

<a href="https://github.com/Panonim/Syncerra">Syncerra</a> © 2025 by <a href="https://github.com/Panonim">Artur Flis</a> is licensed under <a href="https://creativecommons.org/licenses/by-nc-sa/4.0/">CC BY-NC-SA 4.0</a>
