"""Icono procedural de Hearthfolk (cabaña sobre colina, paleta del juego).

Uso: python tools/gen_icon.py
Salida: assets/ui/icons/hearthfolk.png (256) y hearthfolk.ico (multi-tamano)
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "icons")

GRASS = (119, 154, 85, 255)
GRASS_LIGHT = (148, 184, 106, 255)
WOOD = (121, 82, 56, 255)
WOOD_LIGHT = (160, 111, 71, 255)
ROOF = (169, 80, 62, 255)
WARM = (255, 211, 138, 255)
NIGHT = (40, 54, 75, 255)
TEXT = (243, 238, 228, 255)


def draw_icon(size: int = 256) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size / 256.0

    # Disco de cielo nocturno con borde suave
    d.ellipse([8 * s, 8 * s, 248 * s, 248 * s], fill=NIGHT)
    # Luna
    d.ellipse([170 * s, 40 * s, 210 * s, 80 * s], fill=WARM)
    d.ellipse([160 * s, 36 * s, 196 * s, 72 * s], fill=NIGHT)
    # Colina
    d.ellipse([-40 * s, 150 * s, 296 * s, 340 * s], fill=GRASS)
    d.ellipse([-70 * s, 170 * s, 220 * s, 330 * s], fill=GRASS_LIGHT)
    # Cabaña: cuerpo
    d.rectangle([84 * s, 128 * s, 172 * s, 192 * s], fill=WOOD)
    # Tablones
    for y in (144, 160, 176):
        d.line([84 * s, y * s, 172 * s, y * s], fill=WOOD_LIGHT, width=max(1, int(3 * s)))
    # Tejado
    d.polygon(
        [(70 * s, 132 * s), (128 * s, 84 * s), (186 * s, 132 * s)], fill=ROOF
    )
    # Ventana calida
    d.rectangle([138 * s, 146 * s, 160 * s, 168 * s], fill=WARM)
    # Puerta
    d.rectangle([98 * s, 152 * s, 122 * s, 192 * s], fill=WOOD_LIGHT)
    # Humo
    for i, (cx, cy, r) in enumerate([(150, 74, 7), (158, 58, 9), (168, 40, 11)]):
        d.ellipse(
            [(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s],
            fill=(243, 238, 228, 160 - i * 30),
        )
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    icon = draw_icon(256)
    png_path = os.path.join(OUT, "hearthfolk.png")
    ico_path = os.path.join(OUT, "hearthfolk.ico")
    icon.save(png_path)
    icon.save(ico_path, sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("icono generado:", png_path, "y", ico_path)


if __name__ == "__main__":
    main()
