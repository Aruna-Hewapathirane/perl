#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Glib qw(TRUE FALSE);
use Gtk3 -init;

# --- 1. Data Structures for Resistor Bands ---
my %digit_colors = (
    'Black'  => 0, 'Brown' => 1, 'Red'    => 2, 'Orange' => 3, 'Yellow' => 4,
    'Green'  => 5, 'Blue'  => 6, 'Violet' => 7, 'Grey'   => 8, 'White'  => 9
);

my %multiplier_colors = (
    'Black (x1)'      => 1,        'Brown (x10)'    => 10,
    'Red (x100)'      => 100,      'Orange (x1k)'   => 1000,
    'Yellow (x10k)'   => 10000,    'Green (x100k)'  => 100000,
    'Blue (x1M)'      => 1000000,  'Violet (x10M)'  => 10000000,
    'Gold (x0.1)'     => 0.1,      'Silver (x0.01)' => 0.01
);

my %tolerance_colors = (
    'Brown (±1%)'   => '1%',  'Red (±2%)'     => '2%',
    'Green (±0.5%)' => '0.5%','Blue (±0.25%)' => '0.25%',
    'Violet (±0.1%)' => '0.1%', 'Gold (±5%)'    => '5%',
    'Silver (±10%)' => '10%'
);

# --- 2. Main Window Design ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Resistor Color Code Calculator");
$window->set_default_size(450, 250);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

my $vbox = Gtk3::Box->new('vertical', 15);
$vbox->set_border_width(15);
$window->add($vbox);

# --- 3. Grid for Dropdown Selectors ---
my $grid = Gtk3::Grid->new();
$grid->set_row_spacing(10);
$grid->set_column_spacing(15);
$vbox->pack_start($grid, FALSE, FALSE, 0);

# Build the 4 dropdown menus (ComboBoxText)
my $cb1 = Gtk3::ComboBoxText->new();
my $cb2 = Gtk3::ComboBoxText->new();
my $cb3 = Gtk3::ComboBoxText->new();
my $cb4 = Gtk3::ComboBoxText->new();

# Populate Band 1 (Skipping Black)
for my $color (sort { $digit_colors{$a} <=> $digit_colors{$b} } keys %digit_colors) {
    next if $color eq 'Black'; 
    $cb1->append_text($color);
}

# Populate Band 2 (Keeping Black)
for my $color (sort { $digit_colors{$a} <=> $digit_colors{$b} } keys %digit_colors) {
    $cb2->append_text($color);
}

# Populate Band 3 dropdown (Multiplier)
for my $color (sort { $multiplier_colors{$a} <=> $multiplier_colors{$b} } keys %multiplier_colors) {
    $cb3->append_text($color);
}

# Populate Band 4 dropdown (Tolerance sorted alphabetically)
for my $color (sort { $tolerance_colors{$a} cmp $tolerance_colors{$b} } keys %tolerance_colors) {
    $cb4->append_text($color);
}

# Set default active selections (Defaults to 1kOhm ±10%)
$cb1->set_active(0); # Brown (1)
$cb2->set_active(0); # Black (0)
$cb3->set_active(4); # Red (x100) -> (10 * 100 = 1000 Ohms = 1 kΩ)
$cb4->set_active(4); # Silver (±10%)

# --- 4. Add Labels and Comboboxes to Grid ---
$grid->attach(Gtk3::Label->new('Band 1 (Digit 1):'), 0, 0, 1, 1);
$grid->attach($cb1, 1, 0, 1, 1);

$grid->attach(Gtk3::Label->new('Band 2 (Digit 2):'), 0, 1, 1, 1);
$grid->attach($cb2, 1, 1, 1, 1);

$grid->attach(Gtk3::Label->new('Band 3 (Multiplier):'), 0, 2, 1, 1);
$grid->attach($cb3, 1, 2, 1, 1);

$grid->attach(Gtk3::Label->new('Band 4 (Tolerance):'), 0, 3, 1, 1);
$grid->attach($cb4, 1, 3, 1, 1);

# --- 5. Result Display ---
my $result_label = Gtk3::Label->new();
$vbox->pack_start($result_label, TRUE, TRUE, 10);

# --- 6. Calculation Logic ---
sub update_calculation {
    my $b1_text = $cb1->get_active_text();
    my $b2_text = $cb2->get_active_text();
    my $b3_text = $cb3->get_active_text();
    my $b4_text = $cb4->get_active_text();

    return unless defined $b1_text && defined $b2_text && defined $b3_text && defined $b4_text;

    # Fetch numerical values
    my $d1 = $digit_colors{$b1_text};
    my $d2 = $digit_colors{$b2_text};
    my $mult = $multiplier_colors{$b3_text};
    my $tol = $tolerance_colors{$b4_text};

    # Calculate base resistance
    my $resistance = (($d1 * 10) + $d2) * $mult;

    # Format output cleanly (Kilo-ohms, Mega-ohms)
    my $unit = "Ω";
    if ($resistance >= 1_000_000) {
        $resistance /= 1_000_000;
        $unit = "MΩ";
    } elsif ($resistance >= 1_000) {
        $resistance /= 1_000;
        $unit = "kΩ";
    }

    $result_label->set_markup(sprintf("<span size='x-large' weight='bold'>Result: %g %s ±%s</span>", $resistance, $unit, $tol));
}

# Connect change signals to run calculation instantly on selection
$cb1->signal_connect(changed => \&update_calculation);
$cb2->signal_connect(changed => \&update_calculation);
$cb3->signal_connect(changed => \&update_calculation);
$cb4->signal_connect(changed => \&update_calculation);

# Run initial calculation on load
update_calculation();

$window->show_all();
Gtk3::main();

