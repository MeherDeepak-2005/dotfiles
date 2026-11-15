"""Install/update Nerd Fonts' Hack release into the current Linux user's font directory."""
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import tempfile
import urllib.request
import zipfile


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "meher-dotfiles", "Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read()


def main():
    release = json.loads(fetch("https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"))
    asset = next(a for a in release["assets"] if a["name"] == "Hack.zip")
    root = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "fonts/HackNerdFont"
    marker = root / ".release"
    if marker.exists() and marker.read_text().strip() == release["tag_name"] and any(root.glob("*.ttf")):
        print("Hack Nerd Font already current: " + release["tag_name"])
        return
    archive = fetch(asset["browser_download_url"])
    digest = asset.get("digest")
    if not digest or not digest.startswith("sha256:"):
        raise RuntimeError("Release asset lacks a SHA-256 digest; refusing an unverified font download")
    if hashlib.sha256(archive).hexdigest() != digest.split(":", 1)[1]:
        raise RuntimeError("Hack Nerd Font checksum mismatch")
    root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        staged = Path(temp)
        with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
            for entry in bundle.infolist():
                # Extract basenames only; archive paths cannot escape the staging folder.
                if entry.filename.endswith((".ttf", ".otf", "LICENSE.txt", "OFL.txt")):
                    (staged / Path(entry.filename).name).write_bytes(bundle.read(entry))
        if not any(staged.glob("*.ttf")):
            raise RuntimeError("Hack archive contains no TrueType fonts")
        for font in staged.iterdir():
            shutil.copy2(font, root / font.name)
    marker.write_text(release["tag_name"] + "\n")
    print("Installed Hack Nerd Font " + release["tag_name"])


if __name__ == "__main__":
    main()
