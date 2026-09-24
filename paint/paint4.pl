#!/usr/bin/perl
use strict;
use warnings;
use feature ':5.14';

# --- Module Imports (Reordered to fix GLib namespace conflicts) ---
use Gtk3 '-init';
use Pango;
use Cairo::GObject;

# --- Main Application Setup ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Perl Paint");
$window->set_default_size(1000, 700);
$window->signal_connect(delete_event => sub { Gtk3->main_quit });

# Main layout structure: Horizontal box splits Left Panel and Right Artboard
my $main_box = Gtk3::Box->new('horizontal', 6);
$window->add($main_box);

# --- Global Application State ---
my $current_tool  = 'pencil';        # Options: pencil, line, rect, oval, eraser, text
my @current_color = (0.0, 0.0, 0.0); # Default black (RGB 0.0-1.0)
my $brush_size    = 4;
my $fill_enabled  = 0;               # 0 = Outline only, 1 = Solid Filled shapes

# Canvas dimensions
my $canvas_w = 800;
my $canvas_h = 600;

# Surface persistence (Offscreen buffer to hold persistent drawing)
my $surface = Cairo::ImageSurface->create('argb32', $canvas_w, $canvas_h);

# Initialize surface with a solid white sheet background using a temporary context
{
    my $cr_init = Cairo::Context->create($surface);
    $cr_init->set_source_rgb(1.0, 1.0, 1.0);
    $cr_init->paint;
}

# Live stroke state tracking
my $is_drawing = 0;
my ($start_x, $start_y) = (0, 0);
my ($last_x,  $last_y)  = (0, 0);
my ($curr_x,  $curr_y)  = (0, 0);

# --- Vertical Left Sidebar Panel ---
my $left_panel = Gtk3::Box->new('vertical', 8);
$left_panel->set_border_width(8);
$main_box->pack_start($left_panel, 0, 0, 4);

# Tools Category Section Label
my $tools_lbl = Gtk3::Label->new("Tools");
$tools_lbl->set_halign('start');
$left_panel->pack_start($tools_lbl, 0, 0, 2);

# Tool Selector Configuration
my @tools = (
    ['Pencil', 'pencil'],
    ['Line',   'line'],
    ['Rect',   'rect'],
    ['Oval',   'oval'],
    ['Eraser', 'eraser'],
    ['Text',   'text']
);

my $first_radio;
for my $t (@tools) {
    my $radio = Gtk3::RadioButton->new_with_label_from_widget($first_radio, $t->[0]);
    $first_radio //= $radio;
    $radio->set_mode(0); # Display as pressable button toggle blocks
    $radio->set_alignment(0.5, 0.5); 
    $radio->signal_connect(toggled => sub {
        if ($radio->get_active) { $current_tool = $t->[1]; }
    });
    $left_panel->pack_start($radio, 0, 0, 2);
}

# Fill Toggle Options Checkbox
my $fill_chk = Gtk3::CheckButton->new_with_label("Fill Shapes");
$fill_chk->set_active($fill_enabled);
$fill_chk->signal_connect(toggled => sub {
    $fill_enabled = $fill_chk->get_active;
});
$left_panel->pack_start($fill_chk, 0, 0, 2);

$left_panel->pack_start(Gtk3::Separator->new('horizontal'), 0, 0, 6);

# Color Picker Button Section
my $color_lbl = Gtk3::Label->new("Color Selection:");
$color_lbl->set_halign('center');
$left_panel->pack_start($color_lbl, 0, 0, 2);

my $color_btn = Gtk3::ColorButton->new;

$color_btn->set_halign('center');


$color_btn->signal_connect(color_set => sub {
    my $rgba = $color_btn->get_rgba;
    @current_color = ($rgba->red, $rgba->green, $rgba->blue);
});

$left_panel->pack_start($color_btn, 0, 0, 2);

$left_panel->pack_start(Gtk3::Separator->new('horizontal'), 0, 0, 6);

# Brush Size Adjustment Section
my $size_lbl = Gtk3::Label->new("Brush/Font Size:");
$size_lbl->set_halign('start');
$left_panel->pack_start($size_lbl, 0, 0, 2);

my $size_spin = Gtk3::SpinButton->new_with_range(1, 100, 1);
$size_spin->set_value($brush_size);
$size_spin->signal_connect(value_changed => sub {
    $brush_size = $size_spin->get_value_as_int;
});
$left_panel->pack_start($size_spin, 0, 0, 2);

$left_panel->pack_start(Gtk3::Separator->new('horizontal'), 0, 0, 6);

# Actions Section Label
my $actions_lbl = Gtk3::Label->new("Actions");
$actions_lbl->set_halign('start');
$left_panel->pack_start($actions_lbl, 0, 0, 2);

# Clear Screen Utility Button
my $clear_btn = Gtk3::Button->new_with_label("Clear Canvas");
$clear_btn->signal_connect(clicked => sub {
    my $cr_clear = Cairo::Context->create($surface);
    $cr_clear->set_source_rgb(1.0, 1.0, 1.0);
    $cr_clear->paint;
    $window->queue_draw;
});
$left_panel->pack_start($clear_btn, 0, 0, 2);

# NEW: Save Image Native File Selection Button
my $save_btn = Gtk3::Button->new_with_label("Save Image As...");
$save_btn->signal_connect(clicked => sub {
    open_save_dialog();
});
$left_panel->pack_start($save_btn, 0, 0, 2);

# --- Drawing Workspace Frame (Right Side) ---
my $scroll = Gtk3::ScrolledWindow->new;
$scroll->set_policy('automatic', 'automatic');
$main_box->pack_start($scroll, 1, 1, 4);

my $drawing_area = Gtk3::DrawingArea->new;
$drawing_area->set_size_request($canvas_w, $canvas_h);
$drawing_area->add_events(['button-press-mask', 'button-release-mask', 'pointer-motion-mask', 'leave-notify-mask']);
$scroll->add($drawing_area);

# --- Input / Signal Processing Logic ---

# 1. Capture user mouse-down actions
$drawing_area->signal_connect(button_press_event => sub {
    my ($widget, $event) = @_;
    if ($event->button == 1) { # Left Click
        my $x = int($event->x);
        my $y = int($event->y);

        if ($current_tool eq 'text') {
            open_text_dialog($x, $y, $widget);
        } else {
            $is_drawing = 1;
            $start_x = $last_x = $curr_x = $event->x;
            $start_y = $last_y = $curr_y = $event->y;
            
            if ($current_tool eq 'pencil' || $current_tool eq 'eraser') {
                draw_to_surface($last_x, $last_y, $curr_x, $curr_y);
            }
            $widget->queue_draw;
        }
    }
    return 1;
});

# 2. Track real-time drag trajectories and hover mouse states
$drawing_area->signal_connect(motion_notify_event => sub {
    my ($widget, $event) = @_;
    $curr_x = $event->x;
    $curr_y = $event->y;

    if ($is_drawing) {
        if ($current_tool eq 'pencil' || $current_tool eq 'eraser') {
            draw_to_surface($last_x, $last_y, $curr_x, $curr_y);
            $last_x = $curr_x;
            $last_y = $curr_y;
        }
    }
    $widget->queue_draw;
    return 1;
});

# 3. Handle pointer leaving the drawing area
$drawing_area->signal_connect(leave_notify_event => sub {
    my ($widget, $event) = @_;
    $curr_x = -100;
    $curr_y = -100;
    $widget->queue_draw;
    return 1;
});

# 4. Finalize paths on mouse release
$drawing_area->signal_connect(button_release_event => sub {
    my ($widget, $event) = @_;
    if ($event->button == 1 && $is_drawing) {
        $curr_x = $event->x;
        $curr_y = $event->y;
        $is_drawing = 0;

        if ($current_tool eq 'line' || $current_tool eq 'rect' || $current_tool eq 'oval') {
            draw_to_surface($start_x, $start_y, $curr_x, $curr_y);
        }
        $widget->queue_draw;
    }
    return 1;
});

# 5. Viewport refresh controller loop
$drawing_area->signal_connect(draw => sub {
    my ($widget, $cr) = @_;

    # Blit permanent image surface storage back to screen
    $cr->set_source_surface($surface, 0, 0);
    $cr->paint;

    # Dynamic geometric drag overlays
    if ($is_drawing && ($current_tool eq 'line' || $current_tool eq 'rect' || $current_tool eq 'oval')) {
        setup_stroke_context($cr);
        render_shape_path($cr, $start_x, $start_y, $curr_x, $curr_y);
        
        if ($fill_enabled && ($current_tool eq 'rect' || $current_tool eq 'oval')) {
            $cr->fill;
        } else {
            $cr->stroke;
        }
    }

    # Eraser cursor overlay ring
    if ($current_tool eq 'eraser' && $curr_x >= 0 && $curr_y >= 0) {
        $cr->save;
        $cr->set_source_rgba(0.2, 0.2, 0.2, 0.6);
        $cr->set_line_width(1);
        $cr->arc($curr_x, $curr_y, $brush_size / 2, 0, 2 * 3.14159265);
        $cr->stroke;
        $cr->restore;
    }
    
    # Text cursor overlay guidelines
    if ($current_tool eq 'text' && $curr_x >= 0 && $curr_y >= 0) {
        $cr->save;
        $cr->set_source_rgba(0.1, 0.5, 1.0, 0.8);
        $cr->set_line_width(1);
        $cr->move_to($curr_x - 10, $curr_y);
        $cr->line_to($curr_x + 10, $curr_y);
        $cr->move_to($curr_x, $curr_y - 10);
        $cr->line_to($curr_x, $curr_y + 10);
        $cr->stroke;
        $cr->restore;
    }
    return 1;
});

# --- Custom Context Configuration Utilities ---

sub setup_stroke_context {
    my ($cr) = @_;
    $cr->set_line_width($brush_size);
    $cr->set_line_cap('round');
    $cr->set_line_join('round');

    if ($current_tool eq 'eraser') {
        $cr->set_source_rgb(1.0, 1.0, 1.0);
    } else {
        $cr->set_source_rgb(@current_color);
    }
}

sub render_shape_path {
    my ($cr, $x1, $y1, $x2, $y2) = @_;
    if ($current_tool eq 'pencil' || $current_tool eq 'eraser' || $current_tool eq 'line') {
        $cr->move_to($x1, $y1);
        $cr->line_to($x2, $y2);
    } elsif ($current_tool eq 'rect') {
        my $x = $x1 < $x2 ? $x1 : $x2;
        my $y = $y1 < $y2 ? $y1 : $y2;
        my $w = abs($x2 - $x1);
        my $h = abs($y2 - $y1);
        $cr->rectangle($x, $y, $w, $h);
    } elsif ($current_tool eq 'oval') {
        my $x = $x1 < $x2 ? $x1 : $x2;
        my $y = $y1 < $y2 ? $y1 : $y2;
        my $w = abs($x2 - $x1);
        my $h = abs($y2 - $y1);
        
        return if $w < 1 || $h < 1;

        $cr->save;
        $cr->translate($x + $w / 2, $y + $h / 2);
        $cr->scale($w / 2, $h / 2);
        $cr->arc(0, 0, 1, 0, 2 * 3.14159265);
        $cr->restore;
    }
}

sub draw_to_surface {
    my ($x1, $y1, $x2, $y2) = @_;
    my $cr_surf = Cairo::Context->create($surface);
    setup_stroke_context($cr_surf);
    render_shape_path($cr_surf, $x1, $y1, $x2, $y2);
    
    if ($fill_enabled && ($current_tool eq 'rect' || $current_tool eq 'oval')) {
        $cr_surf->fill;
    } else {
        $cr_surf->stroke;
    }
}

# --- Text Placement Core Dialog Engine ---
sub open_text_dialog {
    my ($x, $y, $drawing_widget) = @_;

    my $dialog = Gtk3::Dialog->new_with_buttons(
        "Enter Text", $window, 'modal',
        'gtk-cancel' => 'cancel',
        'gtk-ok'     => 'ok'
    );
$dialog->set_default_response('ok');
my $entry = Gtk3::Entry->new;
$entry->set_activates_default(1);
my $content_area = $dialog->get_content_area;
$content_area->pack_start($entry, 1, 1, 12);
$dialog->show_all;
my $response = $dialog->run;
if ($response eq 'ok') {
    my $text_string = $entry->get_text;
    if ($text_string ne '') {
        my $cr_text = Cairo::Context->create($surface);
        $cr_text->set_source_rgb(@current_color);
        my $pango_layout = Pango::Cairo::create_layout($cr_text);
        $pango_layout->set_text($text_string);
        my $font_desc = Pango::FontDescription->from_string("Sans Bold " . $brush_size);
        $pango_layout->set_font_description($font_desc);
        $cr_text->move_to($x, $y);
        Pango::Cairo::show_layout($cr_text, $pango_layout);
        $drawing_widget->queue_draw;
    }
}
$dialog->destroy;
}
# --- NEW: Native File Exporter Dialog Engine ---
sub open_save_dialog {
    my $file_chooser = Gtk3::FileChooserDialog->new(
        "Save Artwork As PNG",
        $window,
        'save',
        'gtk-cancel' => 'cancel',
        'gtk-save'   => 'accept'
    );
    # Ask the operating system to warn the user if the chosen filename already exists
    $file_chooser->set_do_overwrite_confirmation(1);
    $file_chooser->set_current_name("untitled.png");
    # Add a dedicated filter so only PNG files show up in the chooser target panel
    my $filter = Gtk3::FileFilter->new;
    $filter->set_name("PNG Images (*.png)");
    $filter->add_pattern("*.png");
    $file_chooser->add_filter($filter);
    my $response = $file_chooser->run;
    if ($response eq 'accept') {
        my $filename = $file_chooser->get_filename;
        # Automatically append the extension if the user omitted it
        if ($filename !~ /\.png$/i) {
            $filename .= ".png";
        }
        # Cairo core exports the offscreen surface memory bytes instantly into an image file
        $surface->write_to_png($filename);
    }
    $file_chooser->destroy;
}
# Run program window
$window->show_all;
Gtk3->main;
