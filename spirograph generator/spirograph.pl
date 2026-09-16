#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 '-init';
use Cairo;
use Math::Trig;

# Global parameters for the Spirograph math model
my $R = 150;  # Outer Ring Radius
my $r = 90;   # Inner Rolling Wheel Radius
my $d = 70;   # Pen Distance from inner wheel center
my $color_idx = 0; # Preset selector index

# Color arrays [Red, Green, Blue]
my @colors = (
    [0.1, 0.6, 0.9], # Cyan/Blue
    [0.9, 0.2, 0.4], # Rose/Red
    [0.2, 0.8, 0.4], # Emerald Green
    [0.6, 0.2, 0.8]  # Purple
);

# Create Main Window
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Spirograph Generator (Perl + GTK3 + Cairo)');
$window->set_default_size(850, 550);
$window->set_border_width(10);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

# Layout structure: Split into Control Panel (Left) and Canvas (Right)
my $hbox = Gtk3::Box->new('horizontal', 15);
$window->add($hbox);

# --- LEFT PANEL: INTERACTIVE CONTROLS ---
my $vbox = Gtk3::Box->new('vertical', 12);
$hbox->pack_start($vbox, 0, 0, 5);

my $lbl_title = Gtk3::Label->new();
$lbl_title->set_markup("<b>Spirograph Engine</b>");
$vbox->pack_start($lbl_title, 0, 0, 0);

# Utility function to build unified sliders quickly
sub create_slider {
    my ($label_text, $min, $max, $init_val, $callback) = @_;
    
    my $box = Gtk3::Box->new('vertical', 2);
    my $lbl = Gtk3::Label->new($label_text);
    $lbl->set_alignment(0.0, 0.5);
    
    # Gtk3::Scale configuration (Orientation, Min, Max, Step)
    my $scale = Gtk3::Scale->new_with_range('horizontal', $min, $max, 1);
    $scale->set_value($init_val);
    $scale->set_size_request(220, -1);
    $scale->signal_connect(value_changed => $callback);
    
    $box->pack_start($lbl, 0, 0, 0);
    $box->pack_start($scale, 0, 0, 0);
    return ($box, $scale);
}

# 1. Outer Ring Slider (R)
my ($box_R, $scale_R) = create_slider("Outer Ring Radius (R)", 50, 250, $R, sub {
    $R = $_[0]->get_value();
    trigger_redraw();
});
$vbox->pack_start($box_R, 0, 0, 0);

# 2. Inner Wheel Slider (r)
my ($box_r, $scale_r) = create_slider("Inner Wheel Radius (r)", 10, 200, $r, sub {
    $r = $_[0]->get_value();
    trigger_redraw();
});
$vbox->pack_start($box_r, 0, 0, 0);

# 3. Pen Offset Slider (d)
my ($box_d, $scale_d) = create_slider("Pen Distance (d)", 0, 150, $d, sub {
    $d = $_[0]->get_value();
    trigger_redraw();
});
$vbox->pack_start($box_d, 0, 0, 0);

# 4. Color Palette Cycle Button
my $btn_color = Gtk3::Button->new_with_label("Cycle Color Palette");
$btn_color->signal_connect(clicked => sub {
    $color_idx = ($color_idx + 1) % scalar(@colors);
    trigger_redraw();
});
$vbox->pack_start($btn_color, 0, 0, 10);

# Quick Info label for mathematical explanation
my $lbl_info = Gtk3::Label->new();
$lbl_info->set_markup("<small><i>Uses hypotrochoid curves:\nFormula relies on parametric equations\nmapping ratios of R, r, and d.</i></small>");
$vbox->pack_start($lbl_info, 0, 0, 0);


# --- RIGHT PANEL: CAIRO DRAWING CANVAS ---
my $drawing_area = Gtk3::DrawingArea->new();
$drawing_area->set_size_request(550, 500);
$hbox->pack_start($drawing_area, 1, 1, 0);

sub trigger_redraw {
    $drawing_area->queue_draw(); # Flags GTK to repaint canvas
}

# --- CAIRO MATHEMATICAL MATH ENGINE ---
$drawing_area->signal_connect(draw => sub {
    my ($widget, $cr) = @_;
    
    my $w = $widget->get_allocated_width();
    my $h = $widget->get_allocated_height();
    
    # Fill Canvas Background with deep dark charcoal theme
    $cr->set_source_rgb(0.08, 0.09, 0.1);
    $cr->rectangle(0, 0, $w, $h);
    $cr->fill();
    
    # Move origin coordinate vector center to geometric widget center
    my $cx = $w / 2;
    my $cy = $h / 2;
    $cr->translate($cx, $cy);
    
    # Mathematical calculation setups (Greatest Common Divisor approximation for symmetry)
    # Renders up to 64 complete rotations to fully resolve complex pattern cycles
    my $max_theta = 64 * pi; 
    my $step = 0.02;
    
    $cr->set_line_width(1.2);
    my $c = $colors[$color_idx];
    $cr->set_source_rgba($c->[0], $c->[1], $c->[2], 0.85); # Anti-aliased line transparency
    
    # Parametric Hypotrochoid loop execution
    my $first = 1;
    for (my $theta = 0; $theta < $max_theta; $theta += $step) {
        
        # Hypotrochoid Trigonometric Math Mapping
        my $x = ($R - $r) * cos($theta) + $d * cos((($R - $r) / $r) * $theta);
        my $y = ($R - $r) * sin($theta) - $d * sin((($R - $r) / $r) * $theta);
        
        if ($first) {
            $cr->move_to($x, $y);
            $first = 0;
        } else {
            $cr->line_to($x, $y);
        }
        
        # Performance/Visual optimization boundary safety break
        # Stops loop if the curve seamlessly wraps completely back onto its start coordinate early
        if ($theta > 2 * pi && abs($x - (($R - $r) + $d)) < 0.05 && abs($y) < 0.05) {
            last;
        }
    }
    $cr->stroke();
    
    return 1;
});

# Fire up window loop rendering engine
$window->show_all();
Gtk3::main();

