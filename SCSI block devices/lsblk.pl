#!/usr/bin/env perl
use strict;
use warnings;
use Glib qw(TRUE FALSE);
use Gtk3 '-init';

# Create the main application window
my $window = Gtk3::Window->new('toplevel');
$window->set_title("SCSI Block Devices (lsblk -S)");
$window->set_default_size(775, 400);
$window->signal_connect(destroy => sub { Gtk3::main_quit; });

# Setup a vertical box container with padding
my $vbox = Gtk3::Box->new('vertical', 10);
$vbox->set_border_width(12);
$window->add($vbox);

# Add a title label
my $label = Gtk3::Label->new("Output of 'lsblk -S':");
$label->set_alignment(0, 0.5);
$vbox->pack_start($label, FALSE, FALSE, 0);

# Create a scrolled window wrapper for the text field
my $scrolled_window = Gtk3::ScrolledWindow->new(undef, undef);
$scrolled_window->set_policy('automatic', 'automatic');
$scrolled_window->set_shadow_type('in');
$vbox->pack_start($scrolled_window, TRUE, TRUE, 0);

# Create a TextView container to display the command output
my $text_view = Gtk3::TextView->new();
$text_view->set_editable(FALSE);
$text_view->set_cursor_visible(FALSE);
$text_view->set_left_margin(8);
$text_view->set_right_margin(8);
$text_view->set_top_margin(8);
$text_view->set_bottom_margin(8);

# --- FIX: Apply Monospace Font via CSS ---
my $css_provider = Gtk3::CssProvider->new();
$css_provider->load_from_data("textview { font-family: monospace; font-size: 11pt; }");
my $context = $text_view->get_style_context();
$context->add_provider($css_provider, Gtk3::STYLE_PROVIDER_PRIORITY_APPLICATION);
# ------------------------------------------

$scrolled_window->add($text_view);

# Create a Close button
my $btn_close = Gtk3::Button->new_with_label("Close");
$btn_close->signal_connect(clicked => sub { Gtk3::main_quit; });
$vbox->pack_start($btn_close, FALSE, FALSE, 0);

# Fetch output from system call 'lsblk -S'
my $output = qx(lsblk -S 2>&1);
if ($? != 0) {
    $output = "Error executing command 'lsblk -S':\n$output";
}

# Inject the output text into the view buffer
my $buffer = $text_view->get_buffer();
$buffer->set_text($output);

# Display everything and launch the main loop
$window->show_all();
Gtk3::main();

