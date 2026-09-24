<img width="1007" height="744" alt="image" src="https://github.com/user-attachments/assets/cc54cc3d-3e20-4350-9451-3206349d7e15" /></br>

# 🎨 Perl Paint

A lightweight, hardware-accelerated Microsoft Windows Paint Clone written in pure Perl utilizing modern GTK3 and vector-based Cairo graphics.

## 🚀 Features

* **Creative Toolset:** Includes Pencil, Geometric Lines, Rectangles, Ovals, and an interactive Text insertion tool.
* **Smart Eraser:** Features a dynamic cursor outline ring so you can see your precise brush width before wiping away pixels.
* **Opaque Fills:** Easily toggle between hollow vector outlines and solid filled geometric shapes.
* **Native Exporter:** Save your artwork directly to disk as a high-quality `.png` image using a native Linux system file explorer.
* **Optimized Layout:** Designed with a space-saving vertical left sidebar menu and an auto-scrolling workspace canvas.

---

## 📋 System Requirements & Installation

Before launching the script, you must install the required system development libraries and Perl CPAN binding dependencies.

### 1. Install Linux Package Dependencies (Debian/Ubuntu)
```bash
sudo apt update
sudo apt install libgtk-3-dev libcairo2-dev libgirepository1.0-dev
```

### 2. Install Perl Core Bindings via CPAN
```bash
cpan Gtk3 Cairo::GObject Pango
```

---

## 💻 How to Run the App

Save your completed script as `paint.pl`. Give the file executable permissions and run it from your terminal:

```bash
chmod +x paint.pl
./paint.pl
```

---

## 🎮 How to Use

### 🧰 Selecting Tools
Click any button on the left sidebar to change your active tool.
* **Pencil:** Freehand drawing.
* **Line, Rect, Oval:** Left-click and hold on the canvas, drag to preview your shape, and release to paint it permanently.
* **Eraser:** Cleans your canvas back to solid white. A preview ring traces your mouse position to show your width.
* **Text:** Click anywhere on the canvas to open a text box popup. Type your string and press Enter to render it.

### ⚙️ Adjusting Attributes
* **Changing Colors:** Click the colored box button in the sidebar to open a native system color wheel and select your drawing color.
* **Resizing Brushes & Fonts:** Adjust the numeric spinner value up or down. This dynamically changes the width of your lines, eraser, and the font scale of typed text.
* **Fill Toggle:** Check the **Fill Shapes** box to make rectangles and ovals solid instead of hollow paths.

### 💾 File Operations
* **Clear Canvas:** Wipes out all drawings on screen instantly back to a clean white sheet.
* **Save Image As...:** Opens a file dialog window. Type a filename and select a location on your hard drive to write your file out directly to an image file.
