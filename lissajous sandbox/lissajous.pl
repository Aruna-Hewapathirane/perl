#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 '-init';
use Cairo;
use Math::Trig;

# Global parameters for the Lissajous formula
my $freq_a    = 3;     # X frequency
my $freq_b    = 4;     # Y frequency
my $phase     = 1.57;  # Delta (Phase shift in radians)
my $res_steps = 1000;    # Dropped default so you can immediately see the effect!
my $color_idx = 0;     # Preset color pointer

my @colors = (
    [0.0, 1.0, 0.7],  # Neon Mint
    [1.0, 0.3, 0.6],  # Electric Pink
    [0.2, 0.6, 1.0],  # Cyber Blue
    [1.0, 0.8, 0.0]   # Laser Yellow
);

# Create main application window
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Lissajous Figure Sandbox (Fixed Resolution)');
$window->set_default_size(850, 550);
$window->set_border_width(10);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

# Layout: Split into Controls (Left) and Canvas (Right)
my $hbox = Gtk3::Box->new('horizontal', 15);
$window->add($hbox);

# --- LEFT PANEL: CONTROLS ---
my $vbox = Gtk3::Box->new('vertical', 12);
$hbox->pack_start($vbox, 0, 0, 5);

my $lbl_title = Gtk3::Label->new();
$lbl_title->set_markup("<b>Lissajous Settings</b>");
$vbox->pack_start($lbl_title, 0, 0, 0);

# Helper sub to generate clean control sliders
sub create_slider {
    my ($label_text, $min, $max, $step, $init_val, $callback) = @_;
    my $box = Gtk3::Box->new('vertical', 2);
    my $lbl = Gtk3::Label->new($label_text);
    $lbl->set_alignment(0.0, 0.5);
    
    my $scale = Gtk3::Scale->new_with_range('horizontal', $min, $max, $step);
    $scale->set_value($init_val);
    $scale->set_size_request(220, -1);
    $scale->signal_connect(value_changed => $callback);
    
    $box->pack_start($lbl, 0, 0, 0);
    $box->pack_start($scale, 0, 0, 0);
    return ($box, $scale);
}

# 1. Frequency X Slider (a)
my ($box_a, $scale_a) = create_slider("X Frequency (a)", 1, 12, 1, $freq_a, sub {
    my ($slider) = @_;
    $freq_a = $slider->get_value();
    trigger_redraw();
});
$vbox->pack_start($box_a, 0, 0, 0);

# 2. Frequency Y Slider (b)
my ($box_b, $scale_b) = create_slider("Y Frequency (b)", 1, 12, 1, $freq_b, sub {
    my ($slider) = @_;
    $freq_b = $slider->get_value();
    trigger_redraw();
});
$vbox->pack_start($box_b, 0, 0, 0);

# 3. Phase Shift Slider (δ) - from 0 to 2π
my ($box_p, $scale_p) = create_slider("Phase Shift (δ - Radians)", 0, 6.28, 0.01, $phase, sub {
    my ($slider) = @_;
    $phase = $slider->get_value();
    trigger_redraw();
});
$vbox->pack_start($box_p, 0, 0, 0);

# 4. Curve Resolution Slider (Reduced minimum to 5 to show polygon effects)
my ($box_res, $scale_res) = create_slider("Plot Resolution (Points)", 5, 2000, 1, $res_steps, sub {
    my ($slider) = @_;
    $res_steps = $slider->get_value();
    trigger_redraw();
});
$vbox->pack_start($box_res, 0, 0, 0);

# 5. Cycle Color Button
my $btn_color = Gtk3::Button->new_with_label("Cycle Color Palette");
$btn_color->signal_connect(clicked => sub {
    $color_idx = ($color_idx + 1) % scalar(@colors);
    trigger_redraw();
});
$vbox->pack_start($btn_color, 0, 0, 10);

my $lbl_info = Gtk3::Label->new();
$lbl_info->set_markup("<small><i>Formula:\nx = A * sin(a*t + δ)\ny = B * sin(b*t)</i></small>");
$vbox->pack_start($lbl_info, 0, 0, 0);

# --- RIGHT PANEL: DRAWING CANVAS ---
my $drawing_area = Gtk3::DrawingArea->new();
$drawing_area->set_size_request(550, 500);
$hbox->pack_start($drawing_area, 1, 1, 0);

sub trigger_redraw {
    $drawing_area->queue_draw();
}

# Helper function to find Greatest Common Divisor
sub gcd {
    my ($x, $y) = @_;
    while ($y) {
        ($x, $y) = ($y, $x % $y);
    }
    return $x;
}

# --- CAIRO DRAWING CALLBACK ---
$drawing_area->signal_connect(draw => sub {
    my ($widget, $cr) = @_;
    
    my $w = $widget->get_allocated_width();
    my $h = $widget->get_allocated_height();
    
    # Dark CRT-style background
    $cr->set_source_rgb(0.05, 0.05, 0.07);
    $cr->rectangle(0, 0, $w, $h);
    $cr->fill();
    
    my $scale_x = ($w * 0.8) / 2;
    my $scale_y = ($h * 0.8) / 2;
    
    $cr->translate($w / 2, $h / 2);
    
    # Grid lines
    $cr->set_source_rgba(0.2, 0.2, 0.25, 0.4);
    $cr->set_line_width(1);
    $cr->move_to(-$w/2, 0); $cr->line_to($w/2, 0);
    $cr->move_to(0, -$h/2); $cr->line_to(0, $h/2);
    $cr->stroke();
    
    # Plot curve
    $cr->set_line_width(1.0);
    my $c = $colors[$color_idx];
    $cr->set_source_rgb($c->[0], $c->[1], $c->[2]);
    
    # Math fix: The total time needed to finish a closed Lissajous curve 
    # depends directly on the frequencies used!
    my $factor = gcd($freq_a, $freq_b);
    my $max_t = 2 * pi * ($freq_b / $factor);
    
    # The step size is now tied explicitly to the total step slider value!
    my $step = $max_t / $res_steps;
    
    my $first = 1;
    for (my $t = 0; $t <= $max_t + 0.001; $t += $step) {
        my $x = $scale_x * sin($freq_a * $t + $phase);
        my $y = $scale_y * sin($freq_b * $t);
        
        if ($first) {
            $cr->move_to($x, $y);
            $first = 0;
        } else {
            $cr->line_to($x, $y);
        }
    }
    $cr->stroke();
    
    return 1;
});

# Open operational runtime threads
$window->show_all();
Gtk3::main();

