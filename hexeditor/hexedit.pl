#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 -init;
use Pango;

# Global state to keep track of opened file details
my $current_filepath = '';
my $raw_binary_data  = '';

# 1. Main Window Setup
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Perl + GTK Hex Viewer");
$window->set_default_size(750, 500);
$window->signal_connect(destroy => sub { Gtk3::main_quit() });

# 2. Main Vertical Layout Box
my $vbox = Gtk3::Box->new('vertical', 5);
$vbox->set_border_width(5);
$window->add($vbox);

# 3. Top Toolbar Container
my $toolbar = Gtk3::Box->new('horizontal', 5);
$vbox->pack_start($toolbar, 0, 0, 0);

my $open_btn = Gtk3::Button->new_with_label("Open File");
$open_btn->signal_connect(clicked => \&open_file_dialog);
$toolbar->pack_start($open_btn, 0, 0, 0);

my $save_btn = Gtk3::Button->new_with_label("Save Changes");
$save_btn->signal_connect(clicked => \&save_file_changes);
$toolbar->pack_start($save_btn, 0, 0, 0);

my $status_label = Gtk3::Label->new("No file loaded.");
$status_label->set_xalign(0);
$toolbar->pack_start($status_label, 1, 1, 10);

# 4. Monospace Text Editor Field (Scrollable)
my $scrolled_window = Gtk3::ScrolledWindow->new(undef, undef);
$scrolled_window->set_policy('automatic', 'automatic');
$scrolled_window->set_shadow_type('in');
$vbox->pack_start($scrolled_window, 1, 1, 0);

my $text_view = Gtk3::TextView->new();
my $font_desc = Pango::FontDescription->from_string("Monospace 10");
$text_view->override_font($font_desc);
$scrolled_window->add($text_view);

$window->show_all();
Gtk3::main();

# 5. Core Logic: Read file and format into Standard Hex Layout
sub render_hex_view {
    my $buffer = $text_view->get_buffer();
    
    if (length($raw_binary_data) == 0) {
        $buffer->set_text("[File is empty]");
        return;
    }

    my $formatted_output = "Offset    00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F  Decoded Text\n";
    $formatted_output   .= "--------  -----------------------------------------------  ----------------\n";

    # Process binary data in chunks of 16 bytes
    my $offset = 0;
    while ($offset < length($raw_binary_data)) {
        my $chunk = substr($raw_binary_data, $offset, 16);
        
        # Format the memory offset header (e.g., 00000010)
        $formatted_output .= sprintf("%08X  ", $offset);
        
        # Convert bytes to Hex blocks
        my @bytes = unpack("C*", $chunk);
        my $hex_part = join(' ', map { sprintf("%02X", $_) } @bytes);
        
        # Add padding spaces for short line endings at EOF
        if (scalar(@bytes) < 16) {
            $hex_part .= ' ' x (3 * (16 - scalar(@bytes)) - 1);
        }
        $formatted_output .= "$hex_part  ";
        
        # Convert bytes to human-readable printable text
        my $ascii_part = '';
        for my $byte (@bytes) {
            # Show standard symbols/letters, replace system instructions with a dot
            if ($byte >= 32 && $byte <= 126) {
                $ascii_part .= chr($byte);
            } else {
                $ascii_part .= '.';
            }
        }
        $formatted_output .= "$ascii_part\n";
        $offset += 16;
    }

    $buffer->set_text($formatted_output);
}

# 6. Action Handlers: File System Triggers
sub open_file_dialog {
    my $dialog = Gtk3::FileChooserDialog->new(
        "Open Data File", $window, 'open',
        'gtk-cancel' => 'cancel', 'gtk-open' => 'accept'
    );

    if ($dialog->run eq 'accept') {
        $current_filepath = $dialog->get_filename;
        
        # Read file completely in binary mode
        if (open(my $fh, '<:raw', $current_filepath)) {
            local $/; # Enable slurp mode
            $raw_binary_data = <$fh>;
            close($fh);
            
            $status_label->set_text("Loaded: $current_filepath (" . length($raw_binary_data) . " bytes)");
            render_hex_view();
        } else {
            $status_label->set_text("Error: Could not read file '$!'");
        }
    }
    $dialog->destroy;
}

sub save_file_changes {
    # Guard check for a loaded workspace
    if (!$current_filepath) {
        $status_label->set_text("Error: No file open to save changes to.");
        return;
    }

    # Extract edited string back from text container
    my $buffer = $text_view->get_buffer();
    my $edited_text = $buffer->get_text($buffer->get_start_iter(), $buffer->get_end_iter(), 0);

    # Reconstruct the modified text back into raw binary bytes
    my $reconstructed_binary = '';
    my @lines = split(/\n/, $edited_text);
    
    # Skip the first two header descriptor lines
    for my $i (2 .. $#lines) {
        my $line = $lines[$i];
        next unless $line =~ /^[0-9A-F]{8}\s+((?:[0-9A-F]{2}\s*){1,16})/i;
        
        # Capture raw text Hex segment strings and push directly to array stream
        my $hex_chunk = $1;
        my @hex_bytes = split(/\s+/, $hex_chunk);
        
        foreach my $hex_val (@hex_bytes) {
            next if $hex_val eq '';
            $reconstructed_binary .= pack("C", hex($hex_val));
        }
    }

    # Save to disk
    if (open(my $fh, '>:raw', $current_filepath)) {
        print $fh $reconstructed_binary;
        close($fh);
        $raw_binary_data = $reconstructed_binary; # Update app memory
        $status_label->set_text("Saved successfully: " . length($raw_binary_data) . " bytes.");
        render_hex_view();
    } else {
        $status_label->set_text("Error writing changes to disk: $!");
    }
}

