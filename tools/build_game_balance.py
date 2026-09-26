#!/usr/bin/env python3
"""Build the game's three-civilization reference baseline from archived facts.

The output is intentionally limited to units already implemented by the game.
Mechanics such as targeting and abilities remain explicit game design data in
GDScript; this file supplies sourced costs, ranks, and attack measurements.
"""

from __future__ import annotations

import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "docs" / "aoe4-units"
OUTPUT = ROOT / "data" / "aoe4_balance.json"

SOURCES = {
    "villager": ("chi", "村民"),
    "scout": ("eng", "侦察兵"),
    "spearman": ("eng", "长矛兵"),
    "man_at_arms": ("eng", "武士"),
    "palace_guard": ("chi", "皇宫卫兵"),
    "archer": ("chi", "步弓手"),
    "longbow": ("eng", "长弓兵"),
    "zhuge_nu": ("chi", "诸葛弩手"),
    "fire_lancer": ("chi", "火长矛骑兵"),
    "grenadier": ("chi", "掷弹兵"),
    "crossbowman": ("eng", "弩手"),
    "arbaletrier": ("fre", "弓弩手"),
    "horseman": ("eng", "骑手"),
    "knight": ("eng", "骑士"),
    "royal_knight": ("fre", "皇家骑士"),
    "battering_ram": ("chi", "攻城锤"),
    "trebuchet": ("eng", "配重式巨型投石机"),
    "fishing_boat": ("chi", "渔船"),
    "warship": ("eng", "趸船"),
    "trader": ("chi", "商人"),
    "monk": ("chi", "僧侣"),
}

RESOURCES = {"肉": "food", "木": "wood", "金": "gold", "石": "stone"}
STATS = {"生命值": "hp", "近战护甲": "melee_armor", "远程护甲": "ranged_armor", "火焰护甲": "fire_armor"}


def number(text: str) -> float | None:
    match = re.search(r"[-+]?\d+(?:\.\d+)?", text.replace(",", ""))
    return float(match.group()) if match else None


def range_values(text: str) -> tuple[float | None, float | None]:
    found = [float(value) for value in re.findall(r"\d+(?:\.\d+)?", text)]
    return (found[-1], found[0] if len(found) > 1 else None) if found else (None, None)


def by_age(values: list[dict]) -> dict[str, float | None]:
    if len(values) == 4 and all(value.get("colspan", 1) == 1 for value in values):
        return {str(age): number(value["text"]) for age, value in enumerate(values, 1)}
    value = number(values[0]["text"]) if values else None
    return {str(age): value for age in range(1, 5)}


def resources(value: dict) -> dict[str, int]:
    result = {}
    current = ""
    for part in value.get("parts", []):
        if "icon" in part:
            current = RESOURCES.get(part["icon"], "")
        elif current and (amount := number(part["text"])) is not None:
            result[current] = int(amount)
            current = ""
    return result


def upgrade_age(label: str) -> str | None:
    if "Ⅳ" in label or "IV" in label.upper():
        return "4"
    if "Ⅲ" in label or "III" in label.upper():
        return "3"
    if "Ⅱ" in label or "II" in label.upper():
        return "2"
    return None


def profile_name(section: str, fields: dict) -> str:
    if "冲锋" in section:
        return "charge"
    if "火炬" in section:
        return "torch"
    if "近战狩猎" in section:
        return "hunt_melee"
    if "远程狩猎" in section:
        return "hunt_ranged"
    if "对建筑" in section:
        return "structure"
    if "混战" in section:
        return "melee"
    if "弓箭" in section:
        return "ranged"
    if "远程伤害" in fields:
        return "ranged"
    if "攻城伤害" in fields:
        return "siege"
    return "melee"


def main() -> None:
    units = {}
    for unit_id, (civ, name) in SOURCES.items():
        source = json.loads((ARCHIVE / civ / "units" / f"{name}.json").read_text(encoding="utf-8"))
        sections = source["detail"]["sections"]
        training = next((section for section in sections if section["title"] == "训练信息"), {"fields": []})
        state = next((section for section in sections if section["title"] == "状态数据"), {"fields": []})
        training_fields = {field["label"]: field["values"] for field in training["fields"]}
        state_fields = {field["label"]: field["values"] for field in state["fields"]}
        record = {
            "source_url": source["source_url"],
            "source_name": source["name"],
            "source_civilization": civ,
            "cost": resources(training_fields["成本"][0]) if "成本" in training_fields else {},
            "train_seconds": number(training_fields.get("训练时间", [{"text": ""}])[0]["text"]),
            "move_tiles_per_second": number(state_fields.get("移动速度", [{"text": ""}])[0]["text"]),
            "ranks": {},
            "abilities": [],
            "upgrade_costs": {},
        }
        upgrade_section = next((section for section in sections if section["title"] == "升级费用"), {"fields": []})
        for field in upgrade_section["fields"]:
            age = upgrade_age(field["label"])
            if age and field["values"]:
                record["upgrade_costs"][age] = resources(field["values"][0])
                for index, part in enumerate(field["values"][0].get("parts", [])):
                    if part.get("icon") == "时间" and index + 1 < len(field["values"][0]["parts"]):
                        record["upgrade_costs"][age]["seconds"] = number(field["values"][0]["parts"][index + 1].get("text", ""))
        stat_ages = {key: by_age(state_fields[label]) for label, key in STATS.items() if label in state_fields}
        attack_ages = {}
        for section in sections:
            title = section["title"]
            if not (title.startswith("攻击属性") or title == "冲锋"):
                continue
            fields = {field["label"]: field["values"] for field in section["fields"]}
            profile = profile_name(title, fields)
            damage_label = next((label for label in ("近战伤害", "远程伤害", "火焰伤害", "攻城伤害", "攻击力") if label in fields), None)
            if damage_label is None:
                continue
            attack_ages[profile] = {
                "damage": by_age(fields[damage_label]),
                "damage_kind": "fire" if "火焰" in damage_label else "siege" if "攻城" in damage_label else "ranged" if "远程" in damage_label else "melee",
                "range_tiles": {str(age): range_values(fields["攻击范围"][0]["text"])[0] for age in range(1, 5)} if "攻击范围" in fields and len(fields["攻击范围"]) == 1 else by_age(fields.get("攻击范围", [])),
                "min_range_tiles": {str(age): range_values(fields["攻击范围"][0]["text"])[1] for age in range(1, 5)} if "攻击范围" in fields and len(fields["攻击范围"]) == 1 else {str(age): None for age in range(1, 5)},
                "interval": by_age(fields.get("攻击间隔", [])),
                "hits": by_age(fields.get("多段攻击", [{"text": "1"}])),
                "splash_tiles": by_age(fields.get("伤害区域", [])),
                "bonuses": {
                    label: by_age(values)
                    for label, values in fields.items()
                    if "加成" in label
                },
            }
        abilities_started = False
        for section in sections:
            if section["title"] == "特殊能力":
                abilities_started = True
                continue
            if abilities_started and not section["fields"]:
                record["abilities"].append(section["title"])
            elif abilities_started:
                abilities_started = False
        previous = {}
        for age in range(1, 5):
            key = str(age)
            rank = dict(previous)
            for stat, values in stat_ages.items():
                if values[key] is not None:
                    rank[stat] = values[key]
            attacks = json.loads(json.dumps(previous.get("attacks", {})))
            for profile, fields in attack_ages.items():
                damage = fields["damage"][key]
                if damage is None:
                    continue
                attacks[profile] = {
                    "damage": damage,
                    "damage_kind": fields["damage_kind"],
                    "range_tiles": fields["range_tiles"][key],
                    "min_range_tiles": fields["min_range_tiles"][key],
                    "interval": fields["interval"][key],
                    "hits": int(fields["hits"][key] or 1),
                    "splash_tiles": fields["splash_tiles"][key],
                    "bonuses": {label: amounts[key] for label, amounts in fields["bonuses"].items() if amounts[key] is not None},
                }
            rank["attacks"] = attacks
            if "hp" in rank:
                record["ranks"][key] = rank
                previous = rank
        units[unit_id] = record
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps({
        "source_manifest": "res://docs/aoe4-units/manifest.json",
        "distance_pixels_per_tile": 30,
        "speed_pixels_per_tile_per_second": 80,
        "time_scale": 0.55,
        "units": units,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(units)} unit lines to {OUTPUT}")


if __name__ == "__main__":
    main()
