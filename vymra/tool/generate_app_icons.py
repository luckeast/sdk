from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter
from svgpathtools import parse_path


ROOT = Path(__file__).resolve().parents[1]
BRANDING_DIR = ROOT / "assets" / "branding"
MASTER_PATH = BRANDING_DIR / "app_icon_master.png"
PREVIEW_PATH = BRANDING_DIR / "app_icon_preview.png"
WINDOWS_ICON_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

IOS_ICON_DIR = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
MACOS_ICON_DIR = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
ANDROID_RES_DIR = ROOT / "android" / "app" / "src" / "main" / "res"
WEB_ICON_DIR = ROOT / "web" / "icons"
WEB_ROOT_DIR = ROOT / "web"

SIZE = 1024

# Sketch wash gradient colors matching home app bar background
SKETCH_COLORS = [
    (255, 252, 245),  # #FFFFCF5 warm white
    (234, 251, 255),  # #FFEAFBFF light blue
    (255, 247, 214),  # #FFFFF7D6 light yellow
    (255, 238, 245),  # #FFFFEEF5 light pink
]
SKETCH_STOPS = [0.0, 0.42, 0.74, 1.0]

PAW_COLOR = (36, 59, 83)  # sketchInk #243B53

# Material Icons "pets" SVG data (viewBox 0 0 24 24)
PETS_CIRCLES = [
    (4.5, 9.5, 2.5),
    (9.0, 5.5, 2.5),
    (15.0, 5.5, 2.5),
    (19.5, 9.5, 2.5),
]
PETS_PATH_D = (
    "M17.34 14.86c-.87-1.02-1.6-1.89-2.48-2.91-.46-.54-1.05-1.08-1.75-1.32"
    "-.11-.04-.22-.07-.33-.09-.25-.04-.52-.04-.78-.04s-.53 0-.79.05c-.11.02-.22.05-.33.09"
    "-.7.24-1.28.78-1.75 1.32-.87 1.02-1.6 1.89-2.48 2.91-1.31 1.31-2.92 2.76-2.62 4.79"
    ".29 1.02 1.02 2.03 2.33 2.32.73.15 3.06-.44 5.54-.44h.18c2.48 0 4.81.58 5.54.44"
    " 1.31-.29 2.04-1.31 2.33-2.32.31-2.04-1.3-3.49-2.61-4.8z"
)


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def blend(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(lerp(v1, v2, t) for v1, v2 in zip(c1, c2))


def sketch_gradient(size: int) -> Image.Image:
    """Diagonal gradient matching SketchAppBar background."""
    image = Image.new("RGB", (size, size))
    px = image.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            for i in range(len(SKETCH_STOPS) - 1):
                if SKETCH_STOPS[i] <= t <= SKETCH_STOPS[i + 1]:
                    local_t = (t - SKETCH_STOPS[i]) / (SKETCH_STOPS[i + 1] - SKETCH_STOPS[i])
                    color = blend(SKETCH_COLORS[i], SKETCH_COLORS[i + 1], local_t)
                    break
            else:
                color = SKETCH_COLORS[-1]
            px[x, y] = color
    return image


def build_icon() -> Image.Image:
    base = sketch_gradient(SIZE)
    base = base.filter(ImageFilter.GaussianBlur(radius=2))

    # Create a transparent overlay for the paw shape
    overlay = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(overlay)

    # Material Icons "pets" viewBox is 24x24.
    # Scale to fit nicely in the icon, centered.
    # Full content bbox: x=2..22, y=3..22
    svg_size = 24.0
    scale = SIZE * 0.58 / svg_size
    content_xmin, content_xmax = 2.0, 22.0
    content_ymin, content_ymax = 3.0, 22.0
    center_x_svg = (content_xmin + content_xmax) / 2
    center_y_svg = (content_ymin + content_ymax) / 2
    offset_x = SIZE / 2 - center_x_svg * scale
    offset_y = SIZE / 2 - center_y_svg * scale

    def sx(x: float) -> float:
        return x * scale + offset_x

    def sy(y: float) -> float:
        return y * scale + offset_y

    # Draw circles (toes)
    for cx, cy, r in PETS_CIRCLES:
        x0 = sx(cx - r)
        y0 = sy(cy - r)
        x1 = sx(cx + r)
        y1 = sy(cy + r)
        draw.ellipse([x0, y0, x1, y1], fill=255)

    # Draw main pad from SVG path
    path = parse_path(PETS_PATH_D)
    # Sample the path densely into polygon points
    polygon_points = []
    for seg in path:
        length = seg.length()
        num_samples = max(3, int(length * 15))
        for i in range(num_samples):
            t = i / num_samples
            pt = seg.point(t)
            polygon_points.append((sx(pt.real), sy(pt.imag)))
    # Close the polygon
    if polygon_points:
        polygon_points.append(polygon_points[0])

    if len(polygon_points) >= 3:
        draw.polygon(polygon_points, fill=255)

    # Composite the paw onto the gradient background
    result = Image.new("RGBA", (SIZE, SIZE), (*PAW_COLOR, 0))
    result.putalpha(overlay)

    # Blend onto background
    base_rgba = base.convert("RGBA")
    base_rgba.alpha_composite(result)
    return base_rgba.convert("RGB")


def export_png(image: Image.Image, size: int, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path, format="PNG")


def main() -> None:
    BRANDING_DIR.mkdir(parents=True, exist_ok=True)
    master = build_icon()
    master.save(MASTER_PATH, format="PNG")
    export_png(master, 512, PREVIEW_PATH)

    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, size in ios_sizes.items():
        export_png(master, size, IOS_ICON_DIR / filename)

    macos_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for filename, size in macos_sizes.items():
        export_png(master, size, MACOS_ICON_DIR / filename)

    android_sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for rel_path, size in android_sizes.items():
        export_png(master, size, ANDROID_RES_DIR / rel_path)

    export_png(master, 192, WEB_ICON_DIR / "Icon-192.png")
    export_png(master, 512, WEB_ICON_DIR / "Icon-512.png")
    export_png(master, 192, WEB_ICON_DIR / "Icon-maskable-192.png")
    export_png(master, 512, WEB_ICON_DIR / "Icon-maskable-512.png")
    export_png(master, 64, WEB_ROOT_DIR / "favicon.png")

    WINDOWS_ICON_PATH.parent.mkdir(parents=True, exist_ok=True)
    master.save(
        WINDOWS_ICON_PATH,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    main()
