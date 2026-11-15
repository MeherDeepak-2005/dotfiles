"""Render a native shell path and one shared set of multiplexer bindings."""
import argparse
from pathlib import Path


def quoted(value):
    if "\n" in value or "\r" in value or "\x00" in value:
        raise ValueError("Config paths must not contain newlines or NUL")
    return value.replace("\\", "/").replace("$", "\\$").replace('"', '\\"')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("windows", "macos", "linux"), required=True)
    parser.add_argument("--shell", required=True)
    parser.add_argument("--entry", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    template = root / ("config/multiplexer/psmux.conf" if args.platform == "windows" else "config/tmux/tmux.conf")
    text = template.read_text() + "\n" + (root / "config/multiplexer/shared.conf").read_text()
    text = text.replace("@SHELL@", quoted(args.shell)).replace("@ENTRY@", quoted(args.entry))
    args.output.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
