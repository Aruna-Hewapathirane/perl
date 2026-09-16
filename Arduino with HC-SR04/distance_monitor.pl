#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 '-init';
use Device::SerialPort;

# --- Configuration ---
my $PORT_NAME = '/dev/ttyUSB0'; # Change to /dev/ttyACM0 if necessary
my $BAUD_RATE = 9600;
my $MAX_DISTANCE = 100.0;       # Max distance in cm for the visual progress bar scale

# --- Initialize Serial Port ---
my $port = Device::SerialPort->new($PORT_NAME);
if (!$port) {
    warn "Warning: Could not open serial port $PORT_NAME. Running in Simulation mode.\n";
} else {
    $port->baudrate($BAUD_RATE);
    $port->parity("none");
    $port->databits(8);
    $port->stopbits(1);
    $port->read_char_time(0);
    $port->read_const_time(0);
    $port->write_settings;
}

# --- GUI Setup ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title('HC-SR04 Distance Monitor');
$window->set_border_width(15);
$window->set_default_size(450, 350);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

my $vbox = Gtk3::Box->new('vertical', 15);
$window->add($vbox);

# Header / Distance Display
my $lbl_title = Gtk3::Label->new("Current Distance:");
$vbox->pack_start($lbl_title, 0, 0, 0);

my $lbl_distance = Gtk3::Label->new("-- cm");
# Make the readout text stand out using markup
$lbl_distance->set_markup("<span size='32000' weight='bold' color='#2196F3'>0.00 cm</span>");
$vbox->pack_start($lbl_distance, 0, 0, 0);

# Visual Level Bar (ProgressBar)
my $progress_bar = Gtk3::ProgressBar->new();
$progress_bar->set_text("Distance Level");
$progress_bar->set_show_text(1);
$vbox->pack_start($progress_bar, 0, 0, 0);

# Scrolling Log Frame
my $frame = Gtk3::Frame->new('Raw Serial Log');
$vbox->pack_start($frame, 1, 1, 0);

my $scroll = Gtk3::ScrolledWindow->new();
$scroll->set_policy('automatic', 'automatic');
$frame->add($scroll);

my $text_view = Gtk3::TextView->new();
$text_view->set_editable(0);
my $buffer = $text_view->get_buffer();
$scroll->add($text_view);

# --- Helper Function: Update GUI Elements ---
sub update_ui {
    my ($distance) = @_;
    chomp($distance);
    $distance =~ s/\r//g; # Clean carriage returns
    
    # Only process valid numbers
    return unless $distance =~ /^\d+(\.\d+)?$/;

    # 1. Update the big text label
    $lbl_distance->set_markup("<span size='32000' weight='bold' color='#2196F3'>$distance cm</span>");

    # 2. Update the progress bar fraction (values range strictly from 0.0 to 1.0)
    my $fraction = $distance / $MAX_DISTANCE;
    $fraction = 1.0 if $fraction > 1.0;
    $fraction = 0.0 if $fraction < 0.0;
    $progress_bar->set_fraction($fraction);
    
    # 3. Log to terminal feed
    my $end_iter = $buffer->get_end_iter();
    $buffer->insert($end_iter, "Read: $distance cm\n");
    my $mark = $buffer->get_insert();
    $text_view->scroll_to_mark($mark, 0.0, 0, 0.0, 1.0);
}

# --- Background Serial Processing ---
my $serial_buffer = "";

Glib::Timeout->add(50, sub {
    if ($port) {
        my ($count, $data) = $port->read(255);
        if ($count > 0) {
            $serial_buffer .= $data;
            
            # Process lines when a newline '\n' is encountered
            while ($serial_buffer =~ s/^(.*?)\n//) {
                my $line = $1;
                update_ui($line);
            }
        }
    } else {
        # Simulation Mode when Arduino is unplugged
        # Generates a wave back and forth between 5cm and 95cm
        #my $simulated_distance = 50 + 45 * sin(time() * 2);
        #update_ui(sprintf("%.2f", $simulated_distance));
         # Changed to clearly indicate you are not reading the real hardware
        update_ui("0.00"); 
        my $end_iter = $buffer->get_end_iter();
        $buffer->insert($end_iter, "OFFLINE: Check your USB port or permissions!\n");
    }
    return 1; 
});

$window->show_all();
Gtk3::main();

