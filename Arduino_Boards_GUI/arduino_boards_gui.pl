#!/usr/bin/env perl
use strict;
use warnings;
use Gtk3 '-init';

# 1. Gather Arduino board data
my @boards = fetch_arduino_boards();

# 2. Main Window setup
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Arduino Board Types Lookup');
$window->set_default_size(700, 400);
$window->set_border_width(10);
$window->signal_connect(destroy => sub { Gtk3::main_quit() });

# 3. Layout Box
my $vbox = Gtk3::Box->new('vertical', 6);
$window->add($vbox);

# Title Label
my $label = Gtk3::Label->new("<b>Available Arduino Board Architectures</b>");
$label->set_use_markup(1);
$vbox->pack_start($label, 0, 0, 0);

# 4. Create a Scrollable TreeView (Data Grid)
my $scrolled_window = Gtk3::ScrolledWindow->new(undef, undef);
$scrolled_window->set_policy('automatic', 'automatic');
$vbox->pack_start($scrolled_window, 1, 1, 0);

# ListStore layout: [Board Name (String), FQBN (String)]
my $model = Gtk3::ListStore->new('Glib::String', 'Glib::String');

# Populate model with board data
foreach my $board (@boards) {
    my $iter = $model->append();
    $model->set($iter, 0 => $board->{name}, 1 => $board->{fqbn});
}

my $treeview = Gtk3::TreeView->new_with_model($model);
$scrolled_window->add($treeview);

# Render Column 1: Board Name
my $renderer1 = Gtk3::CellRendererText->new();
my $column1   = Gtk3::TreeViewColumn->new_with_attributes("Board Name", $renderer1, "text" => 0);
$column1->set_resizable(1);
$treeview->append_column($column1);

# Render Column 2: FQBN / Identifier
my $renderer2 = Gtk3::CellRendererText->new();
my $column2   = Gtk3::TreeViewColumn->new_with_attributes("FQBN ID", $renderer2, "text" => 1);
$column2->set_resizable(1);
$treeview->append_column($column2);

# 5. Display UI and enter Main Loop
$window->show_all();
Gtk3::main();

# --- Data Fetching Logic ---
sub fetch_arduino_boards {
    my @list;
    
    # Try calling arduino-cli via system execution
    my $cli_output = `arduino-cli board listall 2>/dev/null`;
    
    if ($cli_output && $? == 0) {
        # Parse official CLI layout
        my @lines = split /\n/, $cli_output;
        shift @lines; # Drop table header
        
        foreach my $line (@lines) {
            # Capture Board Name and FQBN from standard spaced layout
            if ($line =~ /^\s*(.+?)\s{2,}([a-zA-Z0-9_\-]+:[a-zA-Z0-9_\-]+:[a-zA-Z0-9_\-]+)/) {
                push @list, { name => $1, fqbn => $2 };
            }
        }
    }
    
    # Fallback to a core legacy offline dataset if arduino-cli isn't configured
    if (!@list) {
        my @fallback = (
            { name => "Arduino Uno",            fqbn => "arduino:avr:uno" },
            { name => "Arduino Nano",           fqbn => "arduino:avr:nano" },
            { name => "Arduino Mega 2560",      fqbn => "arduino:avr:mega" },
            { name => "Arduino Leonardo",       fqbn => "arduino:avr:leonardo" },
            { name => "Arduino Micro",          fqbn => "arduino:avr:micro" },
            { name => "Arduino Due",            fqbn => "arduino:sam:arduino_due_x" },
            { name => "Arduino Zero",           fqbn => "arduino:samd:arduino_zero_native" },
            { name => "Arduino Nano ESP32",     fqbn => "esp32:esp32:esp32" },
            { name => "Arduino Uno R4 Minima",  fqbn => "arduino:renesas_uno:minima" },
            { name => "Arduino Uno R4 WiFi",    fqbn => "arduino:renesas_uno:unor4wifi" },
        );
        push @list, @fallback;
    }
    
    # Sort alphabetically by board name
    return sort { $a->{name} cmp $b->{name} } @list;
}

