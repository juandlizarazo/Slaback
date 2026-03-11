import SwiftUI
import UniformTypeIdentifiers

struct FileDownloadScriptView: View {
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Label("File Download Script", systemImage: "arrow.down.doc")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("This script downloads all files/images attached to messages in your Slack export. Run it from Terminal after exporting your workspace.")
                    .font(.callout)
                    .foregroundStyle(SlackTheme.secondaryText)

                HStack(spacing: 12) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(scriptContent, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        Label(
                            copied ? "Copied!" : "Copy to Clipboard",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(copied ? Color(hex: "3EB891") : Color(hex: "611f69"))

                    Button {
                        saveScript()
                    } label: {
                        Label("Save as File…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)

                // Usage instructions
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage:")
                        .font(.caption.bold())
                        .foregroundStyle(SlackTheme.secondaryText)
                    Text("bash slack-download-files.sh /path/to/slack-export-folder")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(SlackTheme.primaryText)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "2c2d30"))
                )
                .padding(.top, 4)
            }
            .padding(20)

            Divider()

            // Script content
            ScrollView {
                Text(scriptContent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(hex: "abb2bf"))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(hex: "1e1f22"))
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(SlackTheme.mainBg)
        .preferredColorScheme(.dark)
    }

    private func saveScript() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "slack-download-files.sh"
        panel.allowedContentTypes = [.shellScript]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try scriptContent.write(to: url, atomically: true, encoding: .utf8)
                // Make executable
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: url.path
                )
            } catch {
                // Silently fail — user can still copy-paste
            }
        }
    }
}

private let scriptContent = """
#!/usr/bin/env bash
# slack-download-files.sh
# Downloads all files/images attached to messages in a Slack workspace export.
#
# Usage (from anywhere):
#   bash slack-download-files.sh /path/to/slack-export-folder
#
# Usage (from inside the export folder):
#   bash /path/to/slack-download-files.sh
#
# Downloads are saved to:  <export-folder>/_files/<file-id>/<filename>
# The viewer (index.html) reads from this same _files/ directory automatically.

set -uo pipefail

EXPORT_DIR="${1:-.}"
EXPORT_DIR="$(cd "$EXPORT_DIR" && pwd)"
OUTPUT_DIR="$EXPORT_DIR/_files"

echo "Slack Archive File Downloader"
echo "============================================================"
echo "Export : $EXPORT_DIR"
echo "Output : $OUTPUT_DIR"
echo ""

mkdir -p "$OUTPUT_DIR"

# ── Step 1: scan all message JSON files and collect file records ─────────────

LIST_FILE=$(mktemp /tmp/slack_files_XXXXXX.tsv)
trap 'rm -f "$LIST_FILE"' EXIT

python3 - "$EXPORT_DIR" "$LIST_FILE" << 'PYEOF'
import json, pathlib, sys, unicodedata, re

export_dir = pathlib.Path(sys.argv[1])
list_path  = sys.argv[2]

def safe_filename(name):
    # Normalize unicode, strip control chars, replace problematic chars
    name = unicodedata.normalize("NFC", name)
    name = re.sub(r'[^\\w\\s.\\-]', '_', name).strip()
    return name or "file"

seen = set()
rows = []

for jf in sorted(export_dir.rglob("*.json")):
    # Never touch files inside _files/
    if "_files" in jf.parts:
        continue
    # Only process channel message files: <channel>/YYYY-MM-DD.json (depth 2)
    rel   = jf.relative_to(export_dir)
    parts = rel.parts
    if len(parts) != 2:
        continue
    if not parts[1][0].isdigit():   # skip channels.json, users.json etc.
        continue

    try:
        messages = json.loads(jf.read_text(encoding="utf-8", errors="replace"))
    except Exception as e:
        print(f"  Warning: could not parse {jf.name}: {e}", file=sys.stderr)
        continue

    for msg in messages:
        if not isinstance(msg, dict):
            continue
        for f in msg.get("files", []):
            fid = f.get("id", "")
            if not fid or fid in seen:
                continue
            seen.add(fid)

            name     = safe_filename(f.get("name") or f.get("title") or f"file_{fid}")
            mimetype = f.get("mimetype", "")
            # Prefer url_private_download; fall back to url_private
            url = f.get("url_private_download") or f.get("url_private") or ""
            if not url:
                continue

            rows.append(f"{fid}\\t{name}\\t{mimetype}\\t{url}")

with open(list_path, "w", encoding="utf-8") as fp:
    fp.write("\\n".join(rows))
    if rows:
        fp.write("\\n")

print(f"Found {len(rows)} unique attached file(s).")
PYEOF

TOTAL=$(grep -c . "$LIST_FILE" 2>/dev/null || echo 0)

if [[ "$TOTAL" -eq 0 ]]; then
    echo "No attached files found in this export."
    exit 0
fi

echo "Starting downloads ($TOTAL files)..."
echo ""

DOWNLOADED=0
SKIPPED=0
FAILED=0
IDX=0
PAD=${#TOTAL}

# Clean up any stray .tmp files left by a previous interrupted run
find "$OUTPUT_DIR" -name "*.tmp" -delete 2>/dev/null || true

# Also clean up the current in-progress temp file if we are interrupted
CURRENT_TMP=""
trap 'rm -f "$CURRENT_TMP"; rm -f "$LIST_FILE"' EXIT

while IFS=$'\\t' read -r FILE_ID FILE_NAME MIME URL; do
    [[ -z "$FILE_ID" ]] && continue
    IDX=$((IDX + 1))

    OUT_DIR="$OUTPUT_DIR/$FILE_ID"
    OUT_PATH="$OUT_DIR/$FILE_NAME"
    TMP_PATH="$OUT_DIR/$FILE_NAME.tmp"

    printf "[%${PAD}d/%d] " "$IDX" "$TOTAL"

    # Skip only if the final file is present (not a .tmp — those are incomplete)
    if [[ -f "$OUT_PATH" ]]; then
        printf "skip  %s\\n" "$FILE_NAME"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    mkdir -p "$OUT_DIR"
    CURRENT_TMP="$TMP_PATH"

    # Download to a .tmp file; rename to final name only on HTTP 200.
    # This way an interrupted download never leaves a partial file that
    # would be mistaken for a complete one on the next run.
    HTTP_CODE=$(curl -sS -L -w "%{http_code}" \\
        --max-time 60 \\
        -o "$TMP_PATH" \\
        "$URL" 2>/dev/null)

    if [[ "$HTTP_CODE" == "200" ]]; then
        mv "$TMP_PATH" "$OUT_PATH"
        CURRENT_TMP=""
        SIZE=$(wc -c < "$OUT_PATH" | tr -d ' ')
        printf "ok    %-40s  (%s bytes)\\n" "$FILE_NAME" "$SIZE"
        DOWNLOADED=$((DOWNLOADED + 1))
    else
        rm -f "$TMP_PATH"
        CURRENT_TMP=""
        printf "fail  %-40s  (HTTP %s)\\n" "$FILE_NAME" "$HTTP_CODE"
        FAILED=$((FAILED + 1))
        if [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
            echo ""
            echo "  ⚠  HTTP $HTTP_CODE: Slack auth token has expired."
            echo "     Re-export your workspace to get fresh download URLs."
            echo "     Continuing with remaining files..."
            echo ""
        fi
    fi
done < "$LIST_FILE"

echo ""
echo "============================================================"
printf "  Downloaded : %d\\n"  "$DOWNLOADED"
printf "  Skipped    : %d  (already present)\\n" "$SKIPPED"
printf "  Failed     : %d\\n"  "$FAILED"
echo "============================================================"
echo ""
echo "Files saved to: $OUTPUT_DIR"
echo "Open the Slaback app and load your export to view — local files load automatically."
"""
