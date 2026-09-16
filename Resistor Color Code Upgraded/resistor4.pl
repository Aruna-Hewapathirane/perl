#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Glib qw(TRUE FALSE);
use Gtk3 -init;
use Cairo;

# --- 1. Data Structures and Color Mappings ---
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
    'Brown (±1%)'   => '1%',   'Red (±2%)'     => '2%',
    'Green (±0.5%)' => '0.5%', 'Blue (±0.25%)' => '0.25%',
    'Violet (±0.1%)' => '0.1%', 'Gold (±5%)'    => '5%',
    'Silver (±10%)' => '10%'
);

my %cairo_colors = (
    'Black'          => [0.1, 0.1, 0.1],
    'Brown'          => [0.5, 0.3, 0.1],
    'Red'            => [0.9, 0.1, 0.1],
    'Orange'         => [1.0, 0.5, 0.0],
    'Yellow'         => [0.9, 0.9, 0.0],
    'Green'          => [0.1, 0.6, 0.1],
    'Blue'           => [0.1, 0.3, 0.8],
    'Violet'         => [0.6, 0.2, 0.8],
    'Grey'           => [0.5, 0.5, 0.5],
    'White'          => [0.9, 0.9, 0.9],
    'Gold'           => [0.8, 0.6, 0.2],
    'Silver'         => [0.7, 0.7, 0.7],
    'Black (x1)'     => [0.1, 0.1, 0.1],
    'Brown (x10)'    => [0.5, 0.3, 0.1],
    'Red (x100)'     => [0.9, 0.1, 0.1],
    'Orange (x1k)'   => [1.0, 0.5, 0.0],
    'Yellow (x10k)'  => [0.9, 0.9, 0.0],
    'Green (x100k)'  => [0.1, 0.6, 0.1],
    'Blue (x1M)'     => [0.1, 0.3, 0.8],
    'Violet (x10M)'  => [0.6, 0.2, 0.8],
    'Gold (x0.1)'    => [0.8, 0.6, 0.2],
    'Silver (x0.01)' => [0.7, 0.7, 0.7],
    'Brown (±1%)'    => [0.5, 0.3, 0.1],
    'Red (±2%)'      => [0.9, 0.1, 0.1],
    'Green (±0.5%)'  => [0.1, 0.6, 0.1],
    'Blue (±0.25%)'  => [0.1, 0.3, 0.8],
    'Violet (±0.1%)' => [0.6, 0.2, 0.8],
    'Gold (±5%)'     => [0.8, 0.6, 0.2],
    'Silver (±10%)'  => [0.7, 0.7, 0.7],
);

# --- 2. Main Window & Layout Structure ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Resistor Color Code Calculator");
$window->set_default_size(500, 420);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

my $vbox = Gtk3::Box->new('vertical', 15);
$vbox->set_border_width(15);
$window->add($vbox);

# --- 3. Cairo Canvas Implementation ---
my $drawing_area = Gtk3::DrawingArea->new();
$drawing_area->set_size_request(450, 100);
$vbox->pack_start($drawing_area, FALSE, FALSE, 0);

$drawing_area->signal_connect('draw' => \&draw_resistor_graphic);

# --- 4. Selection Fields Layout (Grid) ---
my $grid = Gtk3::Grid->new();
$grid->set_row_spacing(8);
$grid->set_column_spacing(15);
$vbox->pack_start($grid, FALSE, FALSE, 0);

my $cb1 = Gtk3::ComboBoxText->new();
my $cb2 = Gtk3::ComboBoxText->new();
my $cb3 = Gtk3::ComboBoxText->new();
my $cb4 = Gtk3::ComboBoxText->new();

# --- FIX: Populate Band 1 (Skipping Black) ---
for my $color (sort { $digit_colors{$a} <=> $digit_colors{$b} } keys %digit_colors) {
    next if $color eq 'Black';
    $cb1->append_text($color);
}

# Populate Band 2 (Keeping Black)
for my $color (sort { $digit_colors{$a} <=> $digit_colors{$b} } keys %digit_colors) {
    $cb2->append_text($color);
}

for my $color (sort { $multiplier_colors{$a} <=> $multiplier_colors{$b} } keys %multiplier_colors) {
    $cb3->append_text($color);
}
for my $color (sort keys %tolerance_colors) {
    $cb4->append_text($color);
}

# Initial Default Values (Adjusted for 1k ohm)
$cb1->set_active(0); # Index 0 is Brown (Digit 1)
$cb2->set_active(0); # Index 0 is Black (Digit 0)
$cb3->set_active(4); # Index 4 is Red (Multiplier x100) -> 10 * 100 = 1000 Ohm
$cb4->set_active(5); # Index 5 is Silver (Tolerance ±10%)

$grid->attach(Gtk3::Label->new("1st Band (Digit):"), 0, 0, 1, 1); $grid->attach($cb1, 1, 0, 1, 1); $cb1->set_hexpand(TRUE);
$grid->attach(Gtk3::Label->new("2nd Band (Digit):"), 0, 1, 1, 1); $grid->attach($cb2, 1, 1, 1, 1);
$grid->attach(Gtk3::Label->new("3rd Band (Multiplier):"), 0, 2, 1, 1); $grid->attach($cb3, 1, 2, 1, 1);
$grid->attach(Gtk3::Label->new("4th Band (Tolerance):"), 0, 3, 1, 1); $grid->attach($cb4, 1, 3, 1, 1);

# --- 5. Calculation Result View ---
my $result_label = Gtk3::Label->new();
$vbox->pack_start($result_label, TRUE, TRUE, 5);

# --- 6. Cairo Drawing & Math Handlers ---
sub draw_resistor_graphic {
    my ($widget, $cr) = @_;
    
    my $width  = $widget->get_allocated_width();
    my $height = $widget->get_allocated_height();

    $cr->set_source_rgb(0.96, 0.96, 0.96);
    $cr->rectangle(0, 0, $width, $height);
    $cr->fill();

    my $cy = $height / 2;
    my $cx = $width / 2;

    # 1. Draw metal leads
    $cr->set_source_rgb(0.7, 0.7, 0.7);
    $cr->set_line_width(4);
    $cr->move_to($cx - 180, $cy);
    $cr->line_to($cx + 180, $cy);
    $cr->stroke();

    # 2. Draw Resistor Body
    $cr->set_source_rgb(0.88, 0.78, 0.63);
    $cr->rectangle($cx - 100, $cy - 25, 200, 50);
    $cr->fill();

    my $b1 = $cb1->get_active_text() // 'Brown';
    my $b2 = $cb2->get_active_text() // 'Black';
    my $b3 = $cb3->get_active_text() // 'Red';
    my $b4 = $cb4->get_active_text() // 'Gold';

    # 3. Draw Color Bands
    my $c1 = $cairo_colors{$b1}; $cr->set_source_rgb(@$c1);
    $cr->rectangle($cx - 80, $cy - 25, 12, 50); $cr->fill();

    my $c2 = $cairo_colors{$b2}; $cr->set_source_rgb(@$c2);
    $cr->rectangle($cx - 50, $cy - 25, 12, 50); $cr->fill();

    my $c3 = $cairo_colors{$b3}; $cr->set_source_rgb(@$c3);
    $cr->rectangle($cx - 20, $cy - 25, 12, 50); $cr->fill();

    my $c4 = $cairo_colors{$b4}; $cr->set_source_rgb(@$c4);
    $cr->rectangle($cx + 60, $cy - 25, 12, 50); $cr->fill();

    return TRUE;
}

sub update_application_state {
    my $b1_text = $cb1->get_active_text() // return;
    my $b2_text = $cb2->get_active_text() // return;
    my $b3_text = $cb3->get_active_text() // return;
    my $b4_text = $cb4->get_active_text() // return;

    my $ohms = (($digit_colors{$b1_text} * 10) + $digit_colors{$b2_text}) * $multiplier_colors{$b3_text};
    my $tolerance = $tolerance_colors{$b4_text};

    my $formatted_value;
    if ($ohms >= 1_000_000) { $formatted_value = sprintf("%.2f MΩ", $ohms / 1_000_000); }
    elsif ($ohms >= 1_000)  { $formatted_value = sprintf("%.2f kΩ", $ohms / 1_000); }
    else                    { $formatted_value = sprintf("%.2f Ω", $ohms); }
    $formatted_value =~ s/\.00//;

    $result_label->set_markup("<span size='xx-large' weight='bold' foreground='#2E7D32'>$formatted_value</span> <span size='large' foreground='#555555'>± $tolerance</span>");

    $drawing_area->queue_draw();
}

# --- 7. Event Interceptors & Start ---
$cb1->signal_connect(changed => \&update_application_state);
$cb2->signal_connect(changed => \&update_application_state);
$cb3->signal_connect(changed => \&update_application_state);
$cb4->signal_connect(changed => \&update_application_state);

update_application_state();
$window->show_all();
Gtk3::main();

