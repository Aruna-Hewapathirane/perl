#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 -init;

# 1. Main Window Setup
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Perl + GTK Calculator");
$window->set_default_size(250, 320);
$window->set_resizable(0); # Fixed size for layout integrity
$window->signal_connect(destroy => sub { Gtk3::main_quit() });

# 2. Main Box Layout (Vertical structure)
my $vbox = Gtk3::Box->new('vertical', 5);
$vbox->set_border_width(10);
$window->add($vbox);

# 3. Calculator Display Screen
my $entry = Gtk3::Entry->new();
$entry->set_alignment(1); # Right-aligned text
$entry->set_editable(0);  # Direct typing disabled to prevent invalid character errors
$vbox->pack_start($entry, 0, 0, 5);

# 4. Button Grid Setup
my $grid = Gtk3::Grid->new();
$grid->set_row_spacing(5);
$grid->set_column_spacing(5);
$vbox->pack_start($grid, 1, 1, 0);

# Define button matrix layout
my @buttons = (
    ['C', '(', ')', '/'],
    ['7', '8', '9', '*'],
    ['4', '5', '6', '-'],
    ['1', '2', '3', '+'],
    ['0', '.', '=', ''] # Empty space handled cleanly
);

# 5. Build Grid Layout programmatically
for my $row (0 .. $#buttons) {
    for my $col (0 .. $#{$buttons[$row]}) {
        my $label = $buttons[$row][$col];
        next if $label eq ''; # Skip spacer cells
        
        my $btn = Gtk3::Button->new_with_label($label);
        $btn->set_hexpand(1);
        $btn->set_vexpand(1);
        
        # Connect action dynamically based on button type
        $btn->signal_connect(clicked => sub { handle_click($label) });
        
        # Grid parameters: widget, column index, row index, column span, row span
        $grid->attach($btn, $col, $row, 1, 1);
    }
}

$window->show_all();
Gtk3::main();

# 6. Calculator Logic Handler
sub handle_click {
    my $char = shift;
    my $current_text = $entry->get_text();

    if ($char eq 'C') {
        # Clear screen
        $entry->set_text('');
    } 
    elsif ($char eq '=') {
        # Evaluate arithmetic string safely
        if ($current_text ne '') {
            # Basic validation: ensure only mathematical characters are evaluated
            if ($current_text =~ m{^[0-9.+\-*/() ]+$}) {
                # Wrap evaluate block inside 'eval' to catch runtime crashes like Division by Zero
                my $result = eval $current_text;
                if ($@) {
                    $entry->set_text("Error");
                } else {
                    $entry->set_text($result);
                }
            } else {
                $entry->set_text("Invalid Entry");
            }
        }
    } 
    else {
        # Append typed digits or operators to screen string
        # Clean up existing error text if starting a fresh equation
        if ($current_text eq "Error" || $current_text eq "Invalid Entry") {
            $entry->set_text($char);
        } else {
            $entry->set_text($current_text . $char);
        }
    }
}
