"""Derive Android icons from the existing CampusHub logo; no generated artwork.

Run with the project backend Python (Pillow is a development-only dependency).
The launcher uses an opaque white background; the small notification icon must
keep a transparent background because Android tints its alpha mask.
"""
from pathlib import Path

from PIL import Image, ImageOps


APP = Path(__file__).resolve().parents[1]
RES = APP / "android/app/src/main/res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def centered(logo, size, fraction, background):
    """Return a square RGBA canvas with the complete logo centered inside it."""
    canvas = Image.new("RGBA", (size, size), background)
    limit = round(size * fraction)
    scaled = ImageOps.contain(logo, (limit, limit), Image.Resampling.LANCZOS)
    canvas.alpha_composite(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2))
    return canvas


def save(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def main():
    source = Image.open(APP / "assets/img/logo_light.png").convert("RGBA")
    bounds = source.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("The existing CampusHub logo is empty")
    logo = source.crop(bounds)
    launcher = centered(logo, 1024, 0.70, "white")
    # Leave extra room for OEM launchers that normalize adaptive foregrounds
    # inside another icon frame; keep the dots and complete CH mark visible.
    foreground = centered(logo, 1024, 44 / 108, (0, 0, 0, 0))
    save(launcher, APP / "assets/img/app_icon.png")
    save(foreground, APP / "assets/img/app_icon_foreground.png")
    save(launcher.resize((256, 256), Image.Resampling.LANCZOS),
         RES / "drawable-nodpi/ic_campushub_logo.png")

    for density, scale in DENSITIES.items():
        launcher_size = round(48 * scale)
        foreground_size = round(108 * scale)
        save(launcher.resize((launcher_size, launcher_size), Image.Resampling.LANCZOS),
             RES / f"mipmap-{density}/ic_launcher.png")
        save(foreground.resize((foreground_size, foreground_size), Image.Resampling.LANCZOS),
             RES / f"mipmap-{density}/ic_launcher_foreground.png")
        # Reuse the actual CH silhouette, with a two-dp transparent safety inset.
        mask = centered(logo, round(24 * scale), 20 / 24, (0, 0, 0, 0)).getchannel("A")
        small = Image.new("RGBA", mask.size, "white")
        small.putalpha(mask)
        save(small, RES / f"drawable-{density}/ic_stat_campushub.png")
    print("Generated CampusHub launcher, foreground and notification icons for five densities.")


if __name__ == "__main__":
    main()
