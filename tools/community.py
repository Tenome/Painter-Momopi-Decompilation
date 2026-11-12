#!/usr/bin/env python3
"""Community level packs: browse, download and submit (docs/COMMUNITY.md).

The community packs live in the repository, in community/packs/<id>/ (pack.zip, meta.json, preview.png). A GitHub Action rebuilds community/index.json from them
and the level editor reads that file (static files, no server of our own). Submitting means putting a folder there with a pull request.

  python tools/community.py list                       the packs of the community
  python tools/community.py download ID [--out DIR]    one pack into packs/community/
  python tools/community.py submit PACK.pmpack --title T --author A --description D [--out DIR]    makes the submission folder (checks it first)
  python tools/community.py validate [community/packs] checks every pack folder (this is what the pull request check runs)
  python tools/community.py index                      rewrites community/index.json from the pack folders

Set PMCOMMUNITY_URL to another base address (an http:// or file:// URL ending in /) to read a different index, for example a fork or a test folder."""
import argparse, datetime, hashlib, io, json, os, re, shutil, sys, urllib.request, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import levelpack as lp

ROOT = lp.ROOT
HERE = lp.RESOURCES                                       # original_levels.json is bundled into the editor exe

REPO = "Tenome/Painter-Momopi-Decompilation"
BRANCH = "master"
DEFAULT_BASE = "https://raw.githubusercontent.com/%s/%s/community/" % (REPO, BRANCH)
UPLOAD_URL = "https://github.com/%s/upload/%s/community/packs" % (REPO, BRANCH)
COMMUNITY_DIR = os.path.join(ROOT, "community")
MAX_ZIP = 8 * 1024 * 1024
MAX_UNPACKED = 24 * 1024 * 1024
MAX_FILE = 6 * 1024 * 1024
ALLOWED_EXT = {".pmpack", ".mml", ".png", ".txt", ".md"}
FORMAT = 1


def base_url():
    u = os.environ.get("PMCOMMUNITY_URL", DEFAULT_BASE)
    return u if u.endswith("/") else u + "/"


def slugify(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return s[:40] or "pack"


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


# ------------------------------------------------------------------ original level hashes (so that copies of the game's own levels are not submitted)
def map_hash(level):
    return hashlib.sha1("".join("".join(str(c) for c in row) for row in level.map).encode()).hexdigest()


def original_hashes():
    p = os.path.join(HERE, "original_levels.json")
    return set(json.load(open(p))) if os.path.exists(p) else set()


# ------------------------------------------------------------------ safe zip reading
def safe_names(z):
    """names of a zip that are safe to extract (no folders above, no drive letters), and the reasons for the others"""
    good, bad = [], []
    for info in z.infolist():
        n = info.filename
        if n.endswith("/"):
            continue
        if n.startswith("/") or ".." in n.replace("\\", "/").split("/") or ":" in n or "\\" in n:
            bad.append(n)
        else:
            good.append(n)
    return good, bad


def extract_zip(zip_path, dest):
    """unpacks a pack zip into dest; returns the path of its .pmpack file. Refuses unsafe names and oversized archives."""
    with zipfile.ZipFile(zip_path) as z:
        good, bad = safe_names(z)
        if bad:
            raise ValueError("the zip has unsafe file names: %s" % ", ".join(bad[:3]))
        if sum(i.file_size for i in z.infolist()) > MAX_UNPACKED:
            raise ValueError("the zip is larger than %d MB unpacked" % (MAX_UNPACKED >> 20))
        os.makedirs(dest, exist_ok=True)
        pack = None
        for n in good:
            target = os.path.join(dest, *n.split("/"))
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with z.open(n) as src, open(target, "wb") as out:
                shutil.copyfileobj(src, out)
            if n.lower().endswith(".pmpack") and pack is None:
                pack = target
        if not pack:
            raise ValueError("no .pmpack file in the zip")
        return pack


# ------------------------------------------------------------------ the preview picture: flat colours from the map data only (nothing of the game's graphics)
FLAT = [(28, 28, 40), (232, 200, 74), (217, 138, 43), (106, 176, 232)]
WAVE = [(224, 64, 64), (224, 128, 48), (208, 192, 48), (64, 176, 64), (64, 128, 224), (160, 80, 208)]


PREVIEW_TILES = None            # set to a level_editor.Tiles (with the game data found) to draw the previews with the real room tiles instead of flat colours


def preview_png(pack, path, per_row=3, cell=8, tiles=None):
    from PIL import Image, ImageDraw
    tiles = tiles or PREVIEW_TILES
    if tiles is not None and not tiles.ok:
        tiles = None
    if tiles is not None:
        cell = 10
    levels = pack.levels[:6]
    size = 16 * cell
    cols = min(per_row, max(1, len(levels)))
    rows = (len(levels) + cols - 1) // cols
    img = Image.new("RGB", (cols * (size + 6) + 6, rows * (size + 6) + 6), (20, 20, 30))
    d = ImageDraw.Draw(img)
    for i, lv in enumerate(levels):
        ox, oy = 6 + (i % cols) * (size + 6), 6 + (i // cols) * (size + 6)
        look = lv.theme if lv.theme is not None else (16 if i == 32 else i & 15)
        for r in range(16):
            for c in range(16):
                if tiles is not None:
                    img.paste(tiles.cell_image(look, lv.map[r][c], cell), (ox + c * cell, oy + r * cell))
                else:
                    d.rectangle([ox + c * cell, oy + r * cell, ox + c * cell + cell - 1, oy + r * cell + cell - 1], fill=FLAT[lv.map[r][c]])
        for w, spawns in enumerate(lv.waves):
            for kind, x, y, delay in spawns:
                col, row = lp.cell_of(x, y)
                if 0 <= col < 16 and 0 <= row < 16:
                    cx, cy = ox + col * cell + cell // 2, oy + row * cell + cell // 2
                    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=WAVE[w], outline=(0, 0, 0))
        d.rectangle([ox + 7 * cell + 2, oy + 6 * cell + 2, ox + 7 * cell + cell - 3, oy + 6 * cell + cell - 3], outline=(64, 255, 64))
    img.save(path)


# ------------------------------------------------------------------ checks
def check_textures(files):
    """errors for texture PNGs that look like the untouched grey sheets exported from the game"""
    errs = []
    try:
        from PIL import Image
    except ImportError:
        return errs
    for name, data in files:
        if not name.lower().endswith(".png"):
            continue
        try:
            im = Image.open(io.BytesIO(data)).convert("RGB")
        except Exception:
            errs.append("%s is not a readable PNG" % name)
            continue
        if im.width > 4096 or im.height > 4096:
            errs.append("%s is larger than 4096 pixels" % name)
            continue
        px = list(im.resize((min(im.width, 128), min(im.height, 128))).getdata())
        grey = sum(1 for r, g, b in px if r == g == b and r in (0, 85, 170, 255))
        if grey >= 0.97 * len(px) and re.match(r"\d_[0-9a-f]{4}_", os.path.basename(name)):
            errs.append("%s is an untouched sheet exported from the game: only share textures you made yourself" % name)
    return errs


def validate_pack_dir(d):
    """a list of problems of one community/packs/<id> folder (empty = fine)"""
    errs = []
    pid = os.path.basename(d.rstrip("/\\"))
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,39}", pid):
        errs.append("the folder name must be lowercase letters, digits and dashes (at most 40)")
    names = set(os.listdir(d))
    for need in ("pack.zip", "meta.json", "preview.png"):
        if need not in names:
            errs.append("missing " + need)
    extra = names - {"pack.zip", "meta.json", "preview.png"}
    if extra:
        errs.append("unexpected files: " + ", ".join(sorted(extra)))
    if errs:
        return errs
    meta = json.load(open(os.path.join(d, "meta.json"), encoding="utf-8"))
    for key, limit in (("title", 60), ("author", 40), ("description", 600)):
        v = meta.get(key, "")
        if not isinstance(v, str) or not v.strip():
            errs.append("meta.json: %s is empty" % key)
        elif len(v) > limit:
            errs.append("meta.json: %s is longer than %d characters" % (key, limit))
    if meta.get("id") != pid:
        errs.append("meta.json: id must be %s" % pid)
    if meta.get("license") != "MIT":
        errs.append('meta.json: license must be "MIT" (the repository licence): submitting means you agree to it')
    zp = os.path.join(d, "pack.zip")
    if os.path.getsize(zp) > MAX_ZIP:
        errs.append("pack.zip is larger than %d MB" % (MAX_ZIP >> 20))
    if meta.get("sha256") != sha256_of(zp):
        errs.append("meta.json: sha256 does not match pack.zip (make the folder again with the editor or tools/community.py submit)")
    try:
        with zipfile.ZipFile(zp) as z:
            good, bad = safe_names(z)
            if bad:
                errs.append("pack.zip has unsafe file names: " + ", ".join(bad[:3]))
            if sum(i.file_size for i in z.infolist()) > MAX_UNPACKED:
                errs.append("pack.zip is larger than %d MB unpacked" % (MAX_UNPACKED >> 20))
            for i in z.infolist():
                if not i.filename.endswith("/") and (os.path.splitext(i.filename)[1].lower() not in ALLOWED_EXT or i.file_size > MAX_FILE):
                    errs.append("pack.zip: %s is not allowed (only .pmpack, .mml, .png and text files up to %d MB)" % (i.filename, MAX_FILE >> 20))
            pmpacks = [n for n in good if n.lower().endswith(".pmpack")]
            if len(pmpacks) != 1:
                errs.append("pack.zip must hold exactly one .pmpack file (it has %d)" % len(pmpacks))
            else:
                import tempfile
                with tempfile.TemporaryDirectory() as tmp:
                    path = extract_zip(zp, tmp)
                    pack = lp.load(path)
                    errs += ["pack check: " + w for w in lp.problems(pack)]
                    orig = original_hashes()
                    same = sum(1 for lv in pack.levels if map_hash(lv) in orig)
                    if pack.levels and same * 2 > len(pack.levels):
                        errs.append("more than half of the levels are the game's own levels: submit levels you made")
                    if len(pack.levels) != meta.get("levels"):
                        errs.append("meta.json: levels must be %d" % len(pack.levels))
                    errs += check_textures([(n, z.read(n)) for n in good])
    except zipfile.BadZipFile:
        errs.append("pack.zip is not a zip file")
    except ValueError as e:
        errs.append(str(e))
    return errs


# ------------------------------------------------------------------ making a submission
def collect_files(pack, pack_path):
    """{name in the zip: file on disk} for the pack file, its texture folders and its songs"""
    base = os.path.dirname(os.path.abspath(pack_path))
    files = {os.path.basename(pack_path): pack_path}
    refs = [pack.textures] + [lv.textures for lv in pack.levels]
    for rel in refs:
        if not rel:
            continue
        full = rel if os.path.isabs(rel) else os.path.join(base, rel)
        if os.path.isdir(full):
            for root, _, names in os.walk(full):
                for n in names:
                    p = os.path.join(root, n)
                    files[os.path.relpath(p, base).replace(os.sep, "/")] = p
    for lv in pack.levels:
        if lv.song:
            full = lv.song if os.path.isabs(lv.song) else os.path.join(base, lv.song)
            if os.path.exists(full):
                files[os.path.relpath(full, base).replace(os.sep, "/")] = full
    return files


def make_submission(pack_path, title, author, description, out_root, tags=()):
    """writes <out_root>/<id>/{pack.zip, meta.json, preview.png}; returns (folder, problems)"""
    pack = lp.load(pack_path)
    pid = slugify(title)
    d = os.path.join(out_root, pid)
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    files = collect_files(pack, pack_path)
    pack_name = pid + ".pmpack"
    with zipfile.ZipFile(os.path.join(d, "pack.zip"), "w", zipfile.ZIP_DEFLATED) as z:
        for name, full in files.items():
            z.write(full, pack_name if name == os.path.basename(pack_path) else name)
    preview_png(pack, os.path.join(d, "preview.png"))
    meta = {"id": pid, "title": title.strip(), "author": author.strip(), "description": description.strip(), "tags": [t.strip() for t in tags if t.strip()][:6],
            "levels": len(pack.levels), "format": FORMAT, "license": "MIT", "created": datetime.date.today().isoformat(),
            "size": os.path.getsize(os.path.join(d, "pack.zip")), "sha256": sha256_of(os.path.join(d, "pack.zip"))}
    with open(os.path.join(d, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return d, validate_pack_dir(d)


# ------------------------------------------------------------------ the index
def build_index(community_dir=COMMUNITY_DIR):
    packs_dir = os.path.join(community_dir, "packs")
    entries = []
    if os.path.isdir(packs_dir):
        for pid in sorted(os.listdir(packs_dir)):
            d = os.path.join(packs_dir, pid)
            if os.path.isfile(os.path.join(d, "meta.json")):
                m = json.load(open(os.path.join(d, "meta.json"), encoding="utf-8"))
                m["zip"] = "packs/%s/pack.zip" % pid
                m["preview"] = "packs/%s/preview.png" % pid
                entries.append(m)
    index = {"format": FORMAT, "packs": entries}
    with open(os.path.join(community_dir, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return index


def http_get(url, limit=MAX_ZIP + 1024):
    req = urllib.request.Request(url, headers={"User-Agent": "painter-momopie-level-editor"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = r.read(limit + 1)
    if len(data) > limit:
        raise ValueError("the download is larger than allowed")
    return data


def fetch_index(base=None):
    base = base or base_url()
    data = json.loads(http_get(base + "index.json", 4 << 20).decode("utf-8"))
    if data.get("format") != FORMAT:
        raise ValueError("the community index has a newer format: update the editor")
    return data["packs"]


def download(entry, dest_dir, base=None):
    """downloads and checks one pack zip into dest_dir/<id>.zip; returns the path"""
    base = base or base_url()
    data = http_get(base + entry["zip"])
    if hashlib.sha256(data).hexdigest() != entry.get("sha256"):
        raise ValueError("the download does not match its checksum")
    os.makedirs(dest_dir, exist_ok=True)
    path = os.path.join(dest_dir, entry["id"] + ".zip")
    with open(path, "wb") as f:
        f.write(data)
    return path


def fetch_preview(entry, base=None):
    return http_get((base or base_url()) + entry["preview"], 2 << 20)


# ------------------------------------------------------------------ command line
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    p = sub.add_parser("download")
    p.add_argument("id")
    p.add_argument("--out", default=os.path.join(ROOT, "packs", "community"))
    p = sub.add_parser("submit")
    p.add_argument("pack")
    p.add_argument("--title", required=True)
    p.add_argument("--author", required=True)
    p.add_argument("--description", required=True)
    p.add_argument("--tags", default="")
    p.add_argument("--out", default=os.path.join(ROOT, "submissions"))
    p = sub.add_parser("validate")
    p.add_argument("dir", nargs="?", default=os.path.join(COMMUNITY_DIR, "packs"))
    sub.add_parser("index")
    a = ap.parse_args()
    if a.cmd == "list":
        for e in fetch_index():
            print("%-30s %-20s %2d levels  %s" % (e["id"], e["author"], e["levels"], e["title"]))
    elif a.cmd == "download":
        entries = {e["id"]: e for e in fetch_index()}
        if a.id not in entries:
            sys.exit("no pack with that id")
        print("saved", download(entries[a.id], a.out))
    elif a.cmd == "submit":
        d, errs = make_submission(a.pack, a.title, a.author, a.description, a.out, a.tags.split(","))
        for e in errs:
            print("PROBLEM", e)
        print("submission folder:", d)
        if errs:
            sys.exit(1)
        print("Add this folder to community/packs/ with a pull request (see docs/COMMUNITY.md): %s" % UPLOAD_URL)
    elif a.cmd == "validate":
        bad = 0
        if os.path.isdir(a.dir):
            for pid in sorted(os.listdir(a.dir)):
                d = os.path.join(a.dir, pid)
                if os.path.isdir(d):
                    errs = validate_pack_dir(d)
                    print(("FAIL " if errs else "ok   ") + pid)
                    for e in errs:
                        print("     " + e)
                    bad += bool(errs)
        sys.exit(1 if bad else 0)
    elif a.cmd == "index":
        print("%d packs in %s" % (len(build_index()["packs"]), os.path.join(COMMUNITY_DIR, "index.json")))


if __name__ == "__main__":
    main()
