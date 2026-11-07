#!/usr/bin/env python3
"""Write an objdiff-format progress report (what ByteMatch reads): progress/jp/report.json.

    python tools/report.py [--built build/painter_momopie.gb] [--version jp] [--out progress/jp/report.json]

The built ROM comes from RGBDS (`make`). If it is missing, the sources in src/ are assembled with the in-repo reference
assembler (tools/sm83.py), which understands exactly the dialect that tools/gb_dis.py writes. Functions come from
config/functions.tsv; one unit per ROM bank. Bytes outside functions count as data. A function matches when its bytes
equal the original's. The report holds only names, addresses, sizes and percentages (no ROM bytes).
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import gb_dis

ROOT = gb_dis.ROOT
BANK = gb_dis.BANK


def pct(a, b):
    return round(100.0 * a / b, 4) if b else 0.0


def measures(units):
    tc = sum(int(u["measures"]["total_code"]) for u in units)
    mc = sum(int(u["measures"]["matched_code"]) for u in units)
    td = sum(int(u["measures"]["total_data"]) for u in units)
    md = sum(int(u["measures"]["matched_data"]) for u in units)
    tf = sum(u["measures"]["total_functions"] for u in units)
    mf = sum(u["measures"]["matched_functions"] for u in units)
    fz = sum(float(f["fuzzy_match_percent"]) * int(f["size"]) for u in units for f in u["functions"])
    cu = sum(1 for u in units if u["measures"]["complete_code"] == u["measures"]["total_code"]
             and u["measures"]["complete_data"] == u["measures"]["total_data"])
    return {
        "fuzzy_match_percent": round(fz / tc, 4) if tc else 0.0,
        "total_code": str(tc), "matched_code": str(mc), "matched_code_percent": pct(mc, tc),
        "total_data": str(td), "matched_data": str(md), "matched_data_percent": pct(md, td),
        "total_functions": tf, "matched_functions": mf, "matched_functions_percent": pct(mf, tf),
        "complete_code": str(mc), "complete_code_percent": pct(mc, tc),
        "complete_data": str(md), "complete_data_percent": pct(md, td),
        "total_units": len(units), "complete_units": cu,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", default=os.path.join(ROOT, "orig", "painter_momopie.gb"))
    ap.add_argument("--built", default=os.path.join(ROOT, "build", "painter_momopie.gb"))
    ap.add_argument("--version", default="jp")
    ap.add_argument("--out")
    a = ap.parse_args()
    out = a.out or os.path.join(ROOT, "progress", a.version, "report.json")
    rom = gb_dis.Rom(a.rom)
    if os.path.exists(a.built):
        built = open(a.built, "rb").read()
        how = a.built
    else:
        srcs = [open(os.path.join(ROOT, "src", f"bank_{b:02x}.asm"), encoding="utf-8").read()
                for b in range(rom.nbanks)]
        built = b"".join(gb_dis.assemble(rom, srcs))
        how = "reference assembler"
    print("built from", how)
    funcs = {}
    for ln in list(open(os.path.join(ROOT, "config", "functions.tsv")))[1:]:
        b, ad, sz, nm = ln.rstrip("\n").split("\t")
        funcs.setdefault(int(b), []).append((int(ad, 16), int(sz), nm))
    units = []
    for bank in range(rom.nbanks):
        base = bank * BANK
        start = 0 if bank == 0 else BANK
        fl = []
        covered = bytearray(BANK)
        tc = mc = 0
        for ad, sz, nm in sorted(funcs.get(bank, [])):
            o = base + ad - start
            same = sum(1 for i in range(sz) if built[o + i:o + i + 1] == rom.data[o + i:o + i + 1])
            fz = 100.0 * same / sz if sz else 100.0
            for i in range(sz):
                covered[ad - start + i] = 1
            tc += sz
            mc += sz if same == sz else 0
            fl.append({"name": nm, "size": str(sz), "fuzzy_match_percent": round(fz, 4),
                       "metadata": {"virtual_address": str(ad)}})
        td = md = 0
        for i in range(BANK):
            if not covered[i]:
                td += 1
                md += built[base + i:base + i + 1] == rom.data[base + i:base + i + 1]
        nf = len(fl)
        mf = sum(1 for f in fl if f["fuzzy_match_percent"] == 100.0)
        u = {"name": f"main/bank_{bank:02x}", "measures": {
            "fuzzy_match_percent": round(sum(f["fuzzy_match_percent"] * int(f["size"]) for f in fl) / tc, 4) if tc else 0.0,
            "total_code": str(tc), "matched_code": str(mc), "matched_code_percent": pct(mc, tc),
            "total_data": str(td), "matched_data": str(md), "matched_data_percent": pct(md, td),
            "total_functions": nf, "matched_functions": mf, "matched_functions_percent": pct(mf, nf),
            "complete_code": str(mc), "complete_code_percent": pct(mc, tc),
            "complete_data": str(md), "complete_data_percent": pct(md, td),
            "total_units": 1, "complete_units": 1 if mc == tc and md == td else 0},
            "sections": [{"name": ".text", "size": str(tc), "fuzzy_match_percent": pct(mc, tc)},
                         {"name": ".data", "size": str(td), "fuzzy_match_percent": pct(md, td)}],
            "functions": fl}
        units.append(u)
    rep = {"measures": measures(units), "units": units}
    os.makedirs(os.path.dirname(out), exist_ok=True)
    json.dump(rep, open(out, "w", newline="\n"), indent=1)
    m = rep["measures"]
    print(f"{m['matched_functions']} of {m['total_functions']} functions, {m['matched_code_percent']}% of "
          f"{m['total_code']} code bytes, {m['matched_data_percent']}% of {m['total_data']} data bytes -> {out}")


if __name__ == "__main__":
    main()

# keep the README progress bars in step with the report
import subprocess, sys
subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "progress_svg.py")], check=False)
