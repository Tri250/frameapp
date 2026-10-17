"""Format local copyright application drafts using the distributor's own data."""
import argparse
import json
from pathlib import Path
import re

from reportlab.lib.colors import black, HexColor
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "software-copyright"
PAGE_W, PAGE_H = A4


def register_fonts(font):
    pdfmetrics.registerFont(TTFont("CJK", str(font)))
    # The source listing contains Chinese UI strings and comments. A CJK font
    # keeps those characters legible while still rendering ASCII code cleanly.


def footer(c, page, title):
    c.setStrokeColor(HexColor("#B8B8B8"))
    c.setLineWidth(0.35)
    c.line(18 * mm, 13 * mm, PAGE_W - 18 * mm, 13 * mm)
    c.setFont("CJK", 7.5)
    c.setFillColor(HexColor("#555555"))
    c.drawString(18 * mm, 8 * mm, title)
    c.drawRightString(PAGE_W - 18 * mm, 8 * mm, f"第 {page} 页")


def source_lines():
    files = sorted(
        p
        for p in (ROOT / "lib").rglob("*.dart")
        if p.name != "policy_pages.g.dart"
    )
    files += sorted((ROOT / "android").rglob("*.kt"))
    lines = []
    for path in files:
        rel = path.relative_to(ROOT).as_posix()
        lines.append(f"// FILE: {rel}")
        lines.extend(path.read_text(encoding="utf-8").splitlines())
        lines.append("")
    return lines


def draw_source_pdf(path, metadata):
    lines = source_lines()
    page_size = 50
    selected = (lines[: page_size * 30] + lines[-page_size * 30 :]
                if len(lines) > page_size * 60 else lines)
    page_count = (len(selected) + page_size - 1) // page_size
    label = f"{metadata['software_name']} {metadata['version']}"
    c = canvas.Canvas(str(path), pagesize=A4)
    c.setTitle(f"{label} 源程序鉴别材料")
    c.setAuthor(metadata["applicant"])
    for page_index in range(page_count):
        c.setFont("CJK", 8)
        c.setFillColor(black)
        section = ("前 30 页" if page_index < 30 else "后 30 页") if len(lines) > 3000 else "全文"
        c.drawString(18 * mm, PAGE_H - 13 * mm, f"{label} | 源程序鉴别材料 | {section}")
        c.setFont("CJK", 6.1)
        y = PAGE_H - 21 * mm
        start = page_index * page_size
        for offset, line in enumerate(selected[start : start + page_size]):
            numbered = f"{start + offset + 1:04d}  {line}"
            # Fit the entire line; never silently discard source text.
            width = pdfmetrics.stringWidth(numbered, "CJK", 6.1)
            c.setFont("CJK", min(6.1, 6.1 * (PAGE_W - 36 * mm) / max(width, 1)))
            c.drawString(18 * mm, y, numbered)
            y -= 3.9 * mm
        footer(c, page_index + 1, f"{label} | 程序鉴别材料")
        c.showPage()
    c.save()
    return page_count


def markdown_lines(path):
    raw = path.read_text(encoding="utf-8").splitlines()
    out = []
    for line in raw:
        if line.startswith(">"):
            line = line[1:].strip()
        line = re.sub(r"`([^`]*)`", r"\1", line)
        line = re.sub(r"^#{1,6}\s*", "", line)
        line = re.sub(r"^[-*]\s+", "- ", line)
        line = re.sub(r"^\|", "", line)
        line = re.sub(r"\|$", "", line)
        line = line.replace("---", "")
        if not line.strip():
            out.append("")
            continue
        current = ""
        for char in line:
            candidate = current + char
            if current and pdfmetrics.stringWidth(candidate, "CJK", 9.4) > 455:
                out.append(current)
                current = char
            else:
                current = candidate
        out.append(current or "")
    return out


def draw_document_pdf(path, metadata, description):
    lines = markdown_lines(description)
    label = f"{metadata['software_name']} {metadata['version']}"
    # Keep the manual readable: the first page is a cover, then content uses 34 lines/page.
    pages = [
        [
            label,
            "软件功能和技术说明书",
            "",
            "软件鉴别材料配套文档草案",
            "",
            f"申请人：{metadata['applicant']}",
            f"版本：{metadata['version']}",
            f"开发完成日期：{metadata['completion_date']}",
            f"发表状态：{metadata['publication_status']}",
            "",
            "本说明书依据当前仓库实际实现整理。",
            "提交前请核对权利人、开发日期、发表状态和版本号。",
        ]
    ]
    content = lines[:]
    while content:
        pages.append(content[:34])
        content = content[34:]
    c = canvas.Canvas(str(path), pagesize=A4)
    c.setTitle(f"{label} 软件功能和技术说明书")
    c.setAuthor(metadata["applicant"])
    for page_index, page_lines in enumerate(pages, 1):
        if page_index == 1:
            c.setFont("CJK", 22)
            c.setFillColor(black)
            c.drawCentredString(PAGE_W / 2, PAGE_H - 65 * mm, page_lines[0])
            c.setFont("CJK", 13)
            c.drawCentredString(PAGE_W / 2, PAGE_H - 78 * mm, page_lines[1])
            c.setFont("CJK", 10)
            y = PAGE_H - 112 * mm
            for line in page_lines[3:]:
                c.drawCentredString(PAGE_W / 2, y, line)
                y -= 7 * mm
        else:
            c.setFont("CJK", 10)
            c.drawString(18 * mm, PAGE_H - 14 * mm, f"{label} | 软件功能和技术说明书")
            c.setFont("CJK", 9.4)
            y = PAGE_H - 25 * mm
            for line in page_lines:
                c.drawString(18 * mm, y, line)
                y -= 6.8 * mm
        footer(c, page_index, f"{label} | 文档鉴别材料")
        c.showPage()
    c.save()
    return len(pages)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--metadata', required=True, type=Path,
                        help='Private JSON based on the shared metadata example')
    parser.add_argument('--description', required=True, type=Path,
                        help='Completed private Markdown manual')
    parser.add_argument('--font', required=True, type=Path,
                        help='Licensed TTF font with Chinese glyphs')
    parser.add_argument('--output', type=Path, default=OUT)
    args = parser.parse_args()
    metadata = json.loads(args.metadata.read_text(encoding='utf-8'))
    for key in ('software_name', 'version', 'applicant', 'completion_date', 'publication_status'):
        value = metadata.get(key)
        if not isinstance(value, str) or not value.strip() or 'REPLACE_' in value or '待填写' in value:
            parser.error(f'Fill in {key} in your private metadata file')
    description = args.description.read_text(encoding='utf-8')
    if not description.strip() or 'REPLACE_' in description:
        parser.error('Complete the private manual before generating documents')
    register_fonts(args.font)
    args.output.mkdir(parents=True, exist_ok=True)
    source_count = draw_source_pdf(args.output / 'source-materials.pdf', metadata)
    page_count = draw_document_pdf(args.output / 'software-description.pdf', metadata, args.description)
    print(f'source-materials.pdf: {source_count} pages')
    print(f'software-description.pdf: {page_count} pages')


if __name__ == "__main__":
    main()
