#!/usr/bin/env perl
use strict;
use warnings;
use Math::Trig;
use Glib qw(TRUE FALSE);
use Gtk3 '-init';

# --- Application Configuration ---
my $WIDTH      = 700;
my $HEIGHT     = 400;
my $REFRESH_MS = 30; # Animation tick rate (~33 FPS)

# --- Global State Variables ---
my $current_wave = 'Sine';
my $frequency    = 10.0;  # Initial 10Hz
my $amplitude    = 100.0; # Volts/Scale simulation
my $pulse_duty   = 0.25;  # 25% Duty cycle for pulse wave
my $time_offset  = 0.0;   # Animates the horizontal wave shift

# --- Main Window Layout ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Perl+GTK Oscilloscope Simulator");
$window->set_default_size($WIDTH, $HEIGHT);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

my $main_box = Gtk3::Box->new('horizontal', 10);
$window->add($main_box);

# --- 1. The Oscilloscope Display (DrawingArea) ---
my $area = Gtk3::DrawingArea->new();
$area->set_size_request(450, 400);
$area->signal_connect(draw => \&on_draw_screen);
$main_box->pack_start($area, TRUE, TRUE, 0);

# --- 2. Side Control Panel ---
my $control_panel = Gtk3::Box->new('vertical', 12);
$control_panel->set_border_width(10);
$main_box->pack_start($control_panel, FALSE, FALSE, 0);

# Label Title
my $lbl_title = Gtk3::Label->new("<b>OSCILLOSCOPE CONTROLS</b>");
$lbl_title->set_use_markup(TRUE);
$control_panel->pack_start($lbl_title, FALSE, FALSE, 0);

# Waveform Selector Dropdown
my $combo = Gtk3::ComboBoxText->new();
foreach ('Sine', 'Square', 'Triangle', 'Sawtooth', 'Pulse') {
    $combo->append_text($_);
}
$combo->set_active(0);
$combo->signal_connect(changed => sub {
    $current_wave = $combo->get_active_text();
});
$control_panel->pack_start(create_labeled_widget("Waveform:", $combo), FALSE, FALSE, 0);

# Frequency Slider (1Hz to 100Hz)
my $scale_freq = Gtk3::Scale->new_with_range('horizontal', 1.0, 100.0, 1.0);
$scale_freq->set_value($frequency);
$scale_freq->signal_connect(value_changed => sub { $frequency = $scale_freq->get_value(); });
$control_panel->pack_start(create_labeled_widget("Frequency (Hz):", $scale_freq), FALSE, FALSE, 0);

# Amplitude Slider (0 to 150)
my $scale_amp = Gtk3::Scale->new_with_range('horizontal', 10.0, 150.0, 5.0);
$scale_amp->set_value($amplitude);
$scale_amp->signal_connect(value_changed => sub { $amplitude = $scale_amp->get_value(); });
$control_panel->pack_start(create_labeled_widget("Amplitude (Y-Scale):", $scale_amp), FALSE, FALSE, 0);

# Duty Cycle Slider (Only used for Pulse wave, 5% to 95%)
my $scale_duty = Gtk3::Scale->new_with_range('horizontal', 0.05, 0.95, 0.05);
$scale_duty->set_value($pulse_duty);
$scale_duty->signal_connect(value_changed => sub { $pulse_duty = $scale_duty->get_value(); });
$control_panel->pack_start(create_labeled_widget("Pulse Duty Cycle:", $scale_duty), FALSE, FALSE, 0);

# --- Animation Timer Loop ---
Glib::Timeout->add($REFRESH_MS, sub {
    # Increment time offset based on frequency to create a realistic moving beam look
    $time_offset += ($frequency * ($REFRESH_MS / 1000.0)) * 0.1;
    
    # Request the widget redraw itself
    $area->queue_draw();
    return TRUE; # Keep timer running
});

$window->show_all();
Gtk3::main();

# --- Helper Functions ---

# Wraps widgets into organized layout blocks
sub create_labeled_widget {
    my ($text, $widget) = @_;
    my $vbox = Gtk3::Box->new('vertical', 2);
    my $label = Gtk3::Label->new($text);
    $label->set_alignment(0, 0.5);
    $vbox->pack_start($label, FALSE, FALSE, 0);
    $vbox->pack_start($widget, FALSE, FALSE, 0);
    return $vbox;
}

# Drawing handler powered by Cairo
sub on_draw_screen {
    my ($widget, $cr) = @_;
    
    my $w = $widget->get_allocated_width();
    my $h = $widget->get_allocated_height();
    my $mid_y = $h / 2;

    # 1. Background (Classic Retro CRT Grid Style)
    $cr->set_source_rgb(0.02, 0.08, 0.02); # Deep dark green
    $cr->paint();

    # Draw grid lines
    $cr->set_source_rgba(0.0, 0.3, 0.0, 0.4); # Faint glowing grid
    $cr->set_line_width(1.0);
    
    # Vertical grid line marks
    for (my $x = 0; $x < $w; $x += 40) {
        $cr->move_to($x, 0); $cr->line_to($x, $h);
    }
    # Horizontal grid line marks
    for (my $y = 0; $y < $h; $y += 40) {
        $cr->move_to(0, $y); $cr->line_to($w, $y);
    }
    $cr->stroke();

    # Draw Center Horizontal Axis X line
    $cr->set_source_rgba(0.0, 0.5, 0.0, 0.6);
    $cr->move_to(0, $mid_y); $cr->line_to($w, $mid_y);
    $cr->stroke();

    # 2. Mathematical Waveform Render
    $cr->set_source_rgb(0.1, 1.0, 0.2); # Bright phosphorus green beam
    $cr->set_line_width(2.5);
    
    # Trace the waveform coordinates pixel by pixel across X axis
    for (my $x = 0; $x < $w; $x++) {
        # Normalize horizontal X position to a continuous phase value
        my $phase = ($x / $w) * 5.0 * pi * ($frequency / 10) - $time_offset;
        my $y_val = 0;

        if ($current_wave eq 'Sine') {
            $y_val = sin($phase);
        }
        elsif ($current_wave eq 'Square') {
            $y_val = sin($phase) >= 0 ? 1.0 : -1.0;
        }
        elsif ($current_wave eq 'Triangle') {
            # Map a repeating phase to a clean triangular incline/decline balance
            my $norm = ($phase / (2 * pi)) - int($phase / (2 * pi));
            $norm += 1.0 if $norm < 0; # Handle negatives
            $y_val = $norm < 0.5 ? (4 * $norm - 1.0) : (3.0 - 4 * $norm);
        }
        elsif ($current_wave eq 'Sawtooth') {
            # Progressive ramp drop
            my $norm = ($phase / (2 * pi)) - int($phase / (2 * pi));
            $norm += 1.0 if $norm < 0;
            $y_val = 2.0 * $norm - 1.0;
        }
        elsif ($current_wave eq 'Pulse') {
            # Evaluates time signature against active duty ratio bounds
            my $norm = ($phase / (2 * pi)) - int($phase / (2 * pi));
            $norm += 1.0 if $norm < 0;
            $y_val = $norm < $pulse_duty ? 1.0 : -1.0;
        }

        # Project standard coordinate scale to physical window pixels
        my $screen_y = $mid_y - ($y_val * $amplitude);

        if ($x == 0) {
            $cr->move_to($x, $screen_y);
        } else {
            $cr->line_to($x, $screen_y);
        }
    }
    $cr->stroke();
    
    return FALSE;
}

