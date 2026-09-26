#!/usr/bin/env python3
"""Archive structured AoE IV unit/building facts from seicing.com.

The site publishes each civilization's roster as a JavaScript array and each
entry's facts in HTML tables. This script preserves the source's labels and
column order instead of translating them into the game's balance model.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import date
import json
from pathlib import Path
import re
import time
from urllib.parse import unquote, urlparse

from bs4 import BeautifulSoup, NavigableString, Tag
import requests


BASE = "https://seicing.com"
INDEX_URL = f"{BASE}/html/aoe2/index-aoe4units.html?civ=chi"
LIST_URL = f"{BASE}/js/aoe4civ/aoe4list_{{civ}}.js"
TECH_URL = f"{BASE}/js/tech.js"
DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "docs" / "aoe4-units"
HEADERS = {"User-Agent": "AgeOfEmpireLite reference-data-archiver/1.0"}
CIV_TABLE_ID = re.compile(r"^([a-z]{3})Text\d+$")
INVALID_FILENAME = re.compile(r'[\\/:*?"<>|]')


def fetch(url: str) -> str:
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            response = requests.get(url, headers=HEADERS, timeout=30)
            if response.status_code == 404:
                raise FileNotFoundError(f"Source page returned HTTP 404: {url}")
            response.raise_for_status()
            response.encoding = "utf-8"
            return response.text.lstrip("\ufeff")
        except requests.RequestException as error:
            last_error = error
            if attempt < 2:
                time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"Cannot fetch {url}: {last_error}")


def civ_codes() -> list[str]:
    soup = BeautifulSoup(fetch(INDEX_URL), "html.parser")
    return list(dict.fromkeys(
        match.group(1)
        for element in soup.select("[id$=Button0]")
        if (match := re.fullmatch(r"([a-z]{3})Button0", element.get("id", "")))
    ))


def roster(civ: str) -> list[dict]:
    script = fetch(LIST_URL.format(civ=civ))
    match = re.search(r"export\s+const\s+aoe4list\s*=\s*(\[.*\])\s*;?\s*$", script, re.S)
    if not match:
        raise ValueError(f"Unexpected roster format for {civ}")
    # The published array is JavaScript rather than strict JSON: some files
    # leave a trailing comma after the final object.
    return json.loads(re.sub(r",\s*([}\]])", r"\1", match.group(1)))


def kind_for(entry: dict) -> str:
    link = entry["link"]
    if "/unitaoe4/" in link:
        return "units"
    if "/buildingsaoe4/landmark/" in link:
        return "landmarks"
    if "/buildingsaoe4/" in link:
        return "buildings"
    raise ValueError(f"Unknown entry link: {link}")


def detail_url(link: str) -> str:
    return link if link.endswith(".html") else f"{link}.html"


def icon_name(image: Tag) -> str:
    return unquote(Path(urlparse(image.get("src", "")).path).stem)


def cell_data(cell: Tag) -> dict:
    parts: list[dict] = []
    for node in cell.descendants:
        if isinstance(node, Tag) and node.name == "img":
            parts.append({"icon": icon_name(node)})
        elif isinstance(node, NavigableString):
            value = " ".join(str(node).split())
            if value:
                parts.append({"text": value})
    result: dict = {"text": cell.get_text(" ", strip=True)}
    if parts:
        result["parts"] = parts
    if cell.get("colspan"):
        result["colspan"] = int(cell["colspan"])
    if cell.get("rowspan"):
        result["rowspan"] = int(cell["rowspan"])
    return result


def table_rows(table: Tag) -> list[dict]:
    result = []
    for row in table.find_all("tr"):
        cells = [cell_data(cell) for cell in row.find_all(["td", "th"], recursive=False)]
        if cells:
            result.append({"cells": cells})
    return result


def main_sections(table: Tag) -> tuple[str, list[dict]]:
    rows = table_rows(table)
    title = rows[0]["cells"][0]["text"] if rows else ""
    sections: list[dict] = []
    current: dict | None = None
    for row in rows[1:]:
        cells = row["cells"]
        if len(cells) == 1 and cells[0]["text"] and cells[0].get("colspan", 1) >= 4:
            current = {"title": cells[0]["text"], "fields": []}
            sections.append(current)
        elif len(cells) > 1:
            if current is None:
                current = {"title": "", "fields": []}
                sections.append(current)
            field = {"label": cells[0]["text"], "values": cells[1:]}
            if cells[0].get("parts"):
                field["label_parts"] = cells[0]["parts"]
            current["fields"].append(field)
    return title, sections


def table_civ(table: Tag) -> str | None:
    for parent in table.parents:
        if not isinstance(parent, Tag):
            continue
        match = CIV_TABLE_ID.fullmatch(parent.get("id", ""))
        if match:
            return match.group(1)
    return None


def tech_fragments() -> dict[str, tuple[str, str]]:
    script = fetch(TECH_URL)
    result = {}
    for key, markup in re.findall(r'"([^"]+)"\s*:\s*/\*html\*/`([^`]*)`', script):
        parts = markup.rsplit("<br>", 2)
        if len(parts) == 3:
            result[key] = (parts[1], parts[2])
    return result


def resolve_tech_spans(soup: BeautifulSoup, tech: dict[str, tuple[str, str]]) -> None:
    # The site's tech.js fills empty spans at runtime. Mirror that one data
    # substitution so the archived facts match the rendered page.
    for span in soup.select("span[class]"):
        if span.get_text(" ", strip=True) or span.find("img"):
            continue
        for name in span.get("class", []):
            is_cost = name.endswith("成本")
            key = name[:-2] if is_cost else name
            if key not in tech:
                continue
            markup = tech[key][0 if is_cost else 1]
            fragment = BeautifulSoup(markup, "html.parser")
            span.append(fragment)
            break


def filter_for_civ(soup: BeautifulSoup, civ: str) -> None:
    """Apply the site's showCiv rules to static HTML before reading tables."""
    for element in list(soup.find_all(True)):
        if element.attrs is None:  # An ancestor has already been removed.
            continue
        match = CIV_TABLE_ID.fullmatch(element.get("id", ""))
        if match and match.group(1) != civ:
            element.decompose()
            continue
        classes = element.get("class", [])
        allowed = [name.removeprefix("spc_civ") for name in classes if name.startswith("spc_civ")]
        banned = [name.removeprefix("not_civ") for name in classes if name.startswith("not_civ")]
        if (allowed and civ not in allowed) or civ in banned:
            element.decompose()


def parse_detail(html: str, civ: str, tech: dict[str, tuple[str, str]]) -> dict:
    soup = BeautifulSoup(html, "html.parser")
    filter_for_civ(soup, civ)
    resolve_tech_spans(soup, tech)
    main = soup.select_one("table#celp255")
    if main is None:
        raise ValueError("Detail page has no #celp255 facts table")
    title, sections = main_sections(main)
    bonuses = []
    for table in soup.select("table#aoe4de"):
        owner = table_civ(table)
        if owner is None or owner == civ:
            bonuses.append({"civilization": owner, "rows": table_rows(table)})
    gallery_captions = []
    variant_table = soup.select_one("table#empire")
    if variant_table:
        gallery_captions = [
            cell["text"]
            for row in table_rows(variant_table)
            for cell in row["cells"]
            if cell["text"]
        ]
    return {
        "title": title or (soup.title.get_text(" ", strip=True) if soup.title else ""),
        "sections": sections,
        "bonuses": bonuses,
        "gallery_captions": gallery_captions,
    }


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def item_filename(name: str) -> str:
    return INVALID_FILENAME.sub("_", name).strip(" .") + ".json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--civ", action="append", help="Only archive these civilization codes")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    codes = civ_codes()
    if args.civ:
        unknown = set(args.civ) - set(codes)
        if unknown:
            parser.error(f"Unknown civilization codes: {', '.join(sorted(unknown))}")
        codes = [code for code in codes if code in args.civ]

    print(f"Fetching {len(codes)} civilization rosters", flush=True)
    tech = tech_fragments()
    with ThreadPoolExecutor(max_workers=4) as pool:
        roster_futures = {pool.submit(roster, code): code for code in codes}
        rosters = {roster_futures[future]: future.result() for future in as_completed(roster_futures)}

    urls = sorted({detail_url(entry["link"]) for entries in rosters.values() for entry in entries})
    print(f"Fetching {len(urls)} unique detail pages", flush=True)
    pages: dict[str, str] = {}
    missing_pages: list[str] = []
    errors: list[dict] = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        page_futures = {pool.submit(fetch, url): url for url in urls}
        for index, future in enumerate(as_completed(page_futures), 1):
            url = page_futures[future]
            try:
                pages[url] = future.result()
            except FileNotFoundError:
                missing_pages.append(url)
            except Exception as error:
                errors.append({"url": url, "error": str(error)})
            if index % 50 == 0 or index == len(urls):
                print(f"  {index}/{len(urls)} pages", flush=True)

    manifest = {
        "source_index": INDEX_URL,
        "source_roster_template": LIST_URL,
        "source_technology_data": TECH_URL,
        "retrieved_on": date.today().isoformat(),
        "civilizations": [],
        "unique_detail_pages": len(urls),
        "missing_source_pages": sorted(missing_pages),
        "errors": errors,
    }
    for civ in codes:
        entries = rosters[civ]
        catalog = {"civilization": civ, "source_url": LIST_URL.format(civ=civ), "entries": []}
        counts = {"units": 0, "buildings": 0, "landmarks": 0}
        for entry in entries:
            kind = kind_for(entry)
            url = detail_url(entry["link"])
            filename = item_filename(entry["name"])
            relative_path = f"{kind}/{filename}"
            record = {
                "civilization": civ,
                "kind": kind[:-1] if kind != "landmarks" else "landmark",
                "section": entry["section"],
                "name": entry["name"],
                "image_name": entry.get("img", ""),
                "source_url": f"{url}?civ={civ}",
            }
            if url in pages:
                try:
                    record["detail"] = parse_detail(pages[url], civ, tech)
                except Exception as error:
                    errors.append({"url": url, "civilization": civ, "error": str(error)})
            else:
                record["detail_error"] = (
                    "Source page returned HTTP 404" if url in missing_pages else "Source page unavailable"
                )
            write_json(args.output / civ / relative_path, record)
            catalog["entries"].append({
                "kind": kind,
                "section": entry["section"],
                "name": entry["name"],
                "path": relative_path,
            })
            counts[kind] += 1
        write_json(args.output / civ / "catalog.json", catalog)
        manifest["civilizations"].append({"code": civ, "counts": counts})
        print(f"  {civ}: {counts}", flush=True)
    write_json(args.output / "manifest.json", manifest)
    if errors:
        raise RuntimeError(f"Archive finished with {len(errors)} errors; see manifest.json")


if __name__ == "__main__":
    main()
