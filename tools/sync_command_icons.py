#!/usr/bin/env python3
"""Copy the AoE IV reference icons used by the command panel and resource HUD.

The game loads the small, stable asset set in assets/ rather than depending on
the complete reference archive under docs/ at runtime.
"""

import csv
import re
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "docs/aoe4-icons-library"
OUTPUT = ROOT / "assets/ui/command_icons"
RESOURCE_OUTPUT = ROOT / "assets/ui/resource_icons"
RESOURCE_ICONS = {"food": "肉", "wood": "木", "gold": "金", "stone": "石"}

# Game labels differ from a few names in the reference archive. Keep these
# choices explicit so a visually similar but unrelated icon is never picked by
# an approximate filename search.
ALIASES = {
    "outpost": "哨站",
    "palisade_wall": "木栅栏",
    "palisade_gate": "木城门",
    "stone_gate": "石墙城门",
    "siege_workshop": "攻城武器厂",
    "man_at_arms": "武士",
    "palace_guard": "皇宫卫兵",
    "archer": "步弓手",
    "zhuge_nu": "诸葛弩手",
    "arbaletrier": "弓弩手",
    "horseman": "骑手",
    "knight": "骑士",
    "battering_ram": "攻城锤",
    "springald": "扭力弩炮",
    "springald_ship": "扭力弩炮船",
    "incendiary_ship": "爆破船",
    "monk": "僧侣",
    "forged_weapons": "珩磨剑刃",
    "veteran_training": "军事战术训练",
    "archery_drill": "精准训练",
    "cavalry_husbandry": "驯马",
    "enclosures": "圈地",
    "double_broadaxe": "双阔斧",
    "specialized_pick": "特制矿锄",
    "siege_works": "攻城工程学",
    "armored_hull": "装甲船身",
    "shipwrights": "造船工",
}

# Upgrade filenames use the source game's unit names, which sometimes differ
# from both the game's display labels and the base-unit icons above.
UPGRADE_NAMES = {
    "archer": "步弓手",
    "zhuge_nu": "诸葛弩手",
    "horseman": "骑手",
    "knight": "骑士",
    "palace_guard": "皇宫卫兵",
}

# Some upgrade images omit the rank word or use the source game's unit name.
UPGRADE_ICON_OVERRIDES = {
    "rank_man_at_arms_3": "升级到武士",
    "rank_man_at_arms_4": "升级到精锐武士",
    "rank_palace_guard_3": "升级到皇宫卫兵",
    "rank_grenadier_4": "升级到掷弹兵",
    "rank_arbaletrier_4": "升级到精锐弓弩手",
}
EARLY_UPGRADE_ICONS = {"rank_man_at_arms_2": "升级到早期武士"}

# Command and ability IDs do not appear in the building/unit/technology catalogs.
# Keep their approved reference images in the same runtime icon directory.
ACTION_ICON_SOURCES = {
    "palings": ("tech_ability", "拒马"),
    "volley": ("tech_ability", "万箭齐发"),
    "pavise": ("tech_ability", "部署大盾"),
    "helmsman": ("tech_ability", "掌舵人"),
    "convert": ("tech_ability", "招降"),
    "camp": ("tech_ability", "预备营地"),
    "artillery_shot": ("tech_ability", "火炮射击"),
    "hold": ("tech", "就地坚守"),
    "ungarrison": ("tech", "驻扎命令"),
    "trade": ("tech", "交易袋"),
}


def definitions(path: str, constant: str) -> dict[str, str]:
    source = (ROOT / path).read_text(encoding="utf-8")
    body = source.split(f"const {constant} := {{", 1)[1].split("\n}", 1)[0]
    return dict(re.findall(r'^\s*"([a-z_0-9]+)": \{"label": "([^"]+)"', body, re.M))


def copy_icon(rows: list[tuple[str, str, str]], icon_id: str, category: str, name: str) -> bool:
    source = LIBRARY / category / f"{name}.png"
    if not source.is_file():
        return False
    shutil.copyfile(source, OUTPUT / f"{icon_id}.png")
    rows.append((icon_id, category, name))
    return True


def main() -> None:
    if not LIBRARY.is_dir():
        raise SystemExit(
            "Reference icons are optional and not committed; "
            "place them under docs/aoe4-icons-library before syncing."
        )
    OUTPUT.mkdir(parents=True, exist_ok=True)
    RESOURCE_OUTPUT.mkdir(parents=True, exist_ok=True)
    for resource_id, name in RESOURCE_ICONS.items():
        shutil.copyfile(LIBRARY / "tech" / f"{name}.png", RESOURCE_OUTPUT / f"{resource_id}.png")
    rows: list[tuple[str, str, str]] = []
    groups = [
        definitions("scripts/catalogs/game_data.gd", "BUILDINGS"),
        definitions("scripts/catalogs/game_data.gd", "UNITS"),
        definitions("scripts/catalogs/tech_tree.gd", "TECHNOLOGIES"),
        definitions("scripts/catalogs/landmark_catalog.gd", "LANDMARKS"),
    ]
    missing: list[str] = []
    for group in groups:
        for icon_id, label in group.items():
            if icon_id in {"scout_camp", "landmark"}:
                continue
            if not copy_icon(rows, icon_id, "tech", ALIASES.get(icon_id, label)):
                missing.append(f"{icon_id} ({label})")

    units = groups[1]
    for unit_id, label in units.items():
        name = UPGRADE_NAMES.get(unit_id, label)
        for age, rank in ((3, "老练"), (4, "精锐")):
            icon_id = f"rank_{unit_id}_{age}"
            icon_name = UPGRADE_ICON_OVERRIDES.get(icon_id, f"升级到{rank}{name}")
            copy_icon(rows, icon_id, "upgrade", icon_name)
    for icon_id, icon_name in EARLY_UPGRADE_ICONS.items():
        copy_icon(rows, icon_id, "upgrade", icon_name)

    for icon_id, (category, name) in ACTION_ICON_SOURCES.items():
        if not copy_icon(rows, icon_id, category, name):
            missing.append(f"{icon_id} ({name})")

    with (OUTPUT / "sources.csv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.writer(file, lineterminator="\n")
        writer.writerow(("action_id", "library_category", "library_name"))
        writer.writerows(rows)

    print(f"Copied {len(rows)} icons to {OUTPUT.relative_to(ROOT)}")
    print(f"Copied {len(RESOURCE_ICONS)} resource icons to {RESOURCE_OUTPUT.relative_to(ROOT)}")
    if missing:
        print("No matching source icon: " + ", ".join(missing))


if __name__ == "__main__":
    main()
