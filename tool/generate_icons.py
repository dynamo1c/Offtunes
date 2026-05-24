import os
from PIL import Image

def generate_icons():
    source_path = r"C:\Users\Admin\Downloads\edited-photo (2).png"
    project_root = r"c:\Users\Admin\Documents\oddtunes_app-master\oddtunes_app-master"

    if not os.path.exists(source_path):
        print(f"Source file not found at: {source_path}")
        return

    img = Image.open(source_path)

    # 1. Generate Android launcher icons
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    res_dir = os.path.join(project_root, "android", "app", "src", "main", "res")
    for dir_name, size in android_sizes.items():
        target_dir = os.path.join(res_dir, dir_name)
        os.makedirs(target_dir, exist_ok=True)
        target_path = os.path.join(target_dir, "ic_launcher.png")
        resized_img = img.resize((size, size), Image.Resampling.LANCZOS)
        resized_img.save(target_path, "PNG")
        print(f"Generated Android icon: {target_path} ({size}x{size})")

    # 2. Generate Windows .ico launcher icon
    windows_icon_dir = os.path.join(project_root, "windows", "runner", "resources")
    os.makedirs(windows_icon_dir, exist_ok=True)
    windows_icon_path = os.path.join(windows_icon_dir, "app_icon.ico")
    
    # Standard sizes for Windows ICO
    ico_sizes = [(16, 16), (32, 32), (48, 48), (256, 256)]
    img.save(windows_icon_path, format="ICO", sizes=ico_sizes)
    print(f"Generated Windows icon: {windows_icon_path}")

if __name__ == "__main__":
    generate_icons()
