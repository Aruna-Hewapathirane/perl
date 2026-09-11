#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

# Ensure the GTK3 and Glib libraries are available
use Gtk3 '-init';
use Glib;

# FIX: Import the Encode module to fix the degree symbol encoding mismatch
use Encode qw(decode_utf8);

# --- Configuration ---
my $REFRESH_INTERVAL = 2000; # Refresh every 2000ms (2 seconds)

# --- Main Window Setup ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title('System Sensor Monitor');
$window->set_default_size(550, 450);
$window->set_border_width(15);
$window->signal_connect(destroy => sub { Gtk3->main_quit });

# Use a vertical box to structure the layout
my $vbox = Gtk3::Box->new('vertical', 10);
$window->add($vbox);

# Header Label
my $header = Gtk3::Label->new();
$header->set_markup("<span weight='bold' size='large'>Hardware Sensor Readings</span>");
$vbox->pack_start($header, 0, 0, 5);

# Scrolled Window to house our text box if output overflows
my $scrolled_window = Gtk3::ScrolledWindow->new(undef, undef);
$scrolled_window->set_policy('automatic', 'automatic');
$vbox->pack_start($scrolled_window, 1, 1, 0);

# TextView widget for a clean monospace readout
my $textview = Gtk3::TextView->new();
$textview->set_editable(0); # Make text read-only
$textview->set_cursor_visible(0);

# FIX: Force GTK to use its native fixed-width mapping for flawless alignment
$textview->set_monospace(1); 

$scrolled_window->add($textview);

# TextBuffer to safely manipulate the TextView text
my $textbuffer = $textview->get_buffer();

# --- Subroutine to Fetch & Parse Sensor Data ---
sub update_sensors {
    # Run the 'sensors' system utility and capture its raw bytes
    my $raw_output = qx(sensors 2>&1);
    
    # Check if the utility is installed or gave an error
    if ($? != 0 || !$raw_output) {
        $raw_output = "Error: Could not run 'sensors' command.\n" .
                      "Please ensure 'lm-sensors' is installed and configured.";
    }

    # FIX: Decode the terminal's raw UTF-8 bytes into clean Perl string characters.
    # This prevents the raw 2-byte degree character from displaying an extra 'Â'
    my $sensor_output = decode_utf8($raw_output);

    # Safely update the GTK buffer
    $textbuffer->set_text($sensor_output);
    
    # Return 1 to keep the Glib timeout loop running continuously
    return 1;
}

# --- Initialization and Loop Hook ---
# Trigger the first manual update so it isn't blank on launch
update_sensors();

# Create a periodic timer hook to automatically call our sub
Glib::Timeout->add($REFRESH_INTERVAL, \&update_sensors);

# Render layout and kick off the application main loop
$window->show_all();
Gtk3->main();

