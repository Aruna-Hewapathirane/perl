#!/usr/bin/perl
use strict;
use warnings;
use Glib qw(TRUE FALSE);
use Gtk3 -init;

# Comprehensive database of standard 7400-series Logic ICs
my @ttl_database = (
    { id => "7400", name => "Quad 2-Input NAND Gate" },
    { id => "7401", name => "Quad 2-Input NAND Gate (Open Collector)" },
    { id => "7402", name => "Quad 2-Input NOR Gate" },
    { id => "7403", name => "Quad 2-Input NAND Gate (Open Collector Pinout Variant)" },
    { id => "7404", name => "Hex Inverter" },
    { id => "7405", name => "Hex Inverter (Open Collector)" },
    { id => "7406", name => "Hex Inverter Buffer/Driver (30V Open Collector)" },
    { id => "7407", name => "Hex Non-Inverting Buffer/Driver (30V Open Collector)" },
    { id => "7408", name => "Quad 2-Input AND Gate" },
    { id => "7409", name => "Quad 2-Input AND Gate (Open Collector)" },
    { id => "7410", name => "Triple 3-Input NAND Gate" },
    { id => "7411", name => "Triple 3-Input AND Gate" },
    { id => "7412", name => "Triple 3-Input NAND Gate (Open Collector)" },
    { id => "7413", name => "Dual 4-Input NAND Schmitt Trigger" },
    { id => "7414", name => "Hex Inverter Schmitt Trigger" },
    { id => "7416", name => "Hex Inverting Buffer/Driver (15V Open Collector)" },
    { id => "7417", name => "Hex Non-Inverting Buffer/Driver (15V Open Collector)" },
    { id => "7420", name => "Dual 4-Input NAND Gate" },
    { id => "7421", name => "Dual 4-Input AND Gate" },
    { id => "7422", name => "Dual 4-Input NAND Gate (Open Collector)" },
    { id => "7426", name => "Quad 2-Input NAND Buffer (15V Open Collector)" },
    { id => "7427", name => "Triple 3-Input NOR Gate" },
    { id => "7428", name => "Quad 2-Input NOR Buffer" },
    { id => "7430", name => "8-Input NAND Gate" },
    { id => "7432", name => "Quad 2-Input OR Gate" },
    { id => "7433", name => "Quad 2-Input NOR Buffer (Open Collector)" },
    { id => "7437", name => "Quad 2-Input NAND Buffer" },
    { id => "7438", name => "Quad 2-Input NAND Buffer (Open Collector)" },
    { id => "7440", name => "Dual 4-Input NAND Buffer" },
    { id => "7442", name => "BCD to Decimal (1-of-10) Decoder" },
    { id => "7445", name => "BCD to Decimal Decoder/Driver (Open Collector)" },
    { id => "7447", name => "BCD to 7-Segment Decoder/Driver (Open Collector High Current)" },
    { id => "7448", name => "BCD to 7-Segment Decoder/Driver (Internal Pull-ups)" },
    { id => "7470", name => "And-Gated JK Positive-Edge-Triggered Flip-Flop" },
    { id => "7472", name => "AND-Gated JK Master-Slave Flip-Flop" },
    { id => "7473", name => "Dual JK Flip-Flop (With Clear)" },
    { id => "7474", name => "Dual D-Type Positive-Edge-Triggered Flip-Flop (With Preset & Clear)" },
    { id => "7475", name => "4-Bit Bistable D-Type Latch" },
    { id => "7476", name => "Dual JK Flip-Flop (With Preset & Clear)" },
    { id => "7483", name => "4-Bit Binary Full Adder" },
    { id => "7485", name => "4-Bit Magnitude Comparator" },
    { id => "7486", name => "Quad 2-Input XOR Gate" },
    { id => "7489", name => "64-Bit RAM (16x4, Open Collector)" },
    { id => "7490", name => "Decade Counter (Separate Divide-by-2 and Divide-by-5)" },
    { id => "7492", name => "Divide-by-12 Counter" },
    { id => "7493", name => "4-Bit Binary Counter" },
    { id => "7495", name => "4-Bit Shift Register (Parallel In / Parallel Out)" },
    { id => "74107", name => "Dual JK Flip-Flop with Clear (Pinout Variant)" },
    { id => "74109", name => "Dual JK Positive-Edge-Triggered Flip-Flop" },
    { id => "74121", name => "Monostable Multivibrator (One-Shot)" },
    { id => "74122", name => "Retriggerable Monostable Multivibrator" },
    { id => "74123", name => "Dual Retriggerable Monostable Multivibrator" },
    { id => "74125", name => "Quad Bus Buffer (Three-State / Active Low Enable)" },
    { id => "74126", name => "Quad Bus Buffer (Three-State / Active High Enable)" },
    { id => "74132", name => "Quad 2-Input NAND Schmitt Trigger" },
    { id => "74138", name => "3-to-8 Line Decoder/Demultiplexer" },
    { id => "74139", name => "Dual 2-to-4 Line Decoder/Demultiplexer" },
    { id => "74141", name => "BCD to Decimal Decoder/Driver (Nixie Tube Driver)" },
    { id => "74145", name => "BCD to Decimal Decoder/Driver" },
    { id => "74147", name => "10-Line to 4-Line Priority Encoder" },
    { id => "74148", name => "8-Line to 3-Line Priority Encoder" },
    { id => "74150", name => "16-Line to 1-Line Data Selector/Multiplexer" },
    { id => "74151", name => "8-Line to 1-Line Data Selector/Multiplexer" },
    { id => "74153", name => "Dual 4-Line to 1-Line Data Selector/Multiplexer" },
    { id => "74154", name => "4-to-16 Line Decoder/Demultiplexer" },
    { id => "74157", name => "Quad 2-Line to 1-Line Multiplexer (Non-Inverting)" },
    { id => "74158", name => "Quad 2-Line to 1-Line Multiplexer (Inverting)" },
    { id => "74160", name => "Synchronous Presettable BCD Counter (Asynchronous Clear)" },
    { id => "74161", name => "Synchronous Presettable 4-Bit Binary Counter (Asynchronous Clear)" },
    { id => "74162", name => "Synchronous Presettable BCD Counter (Synchronous Clear)" },
    { id => "74163", name => "Synchronous Presettable 4-Bit Binary Counter (Synchronous Clear)" },
    { id => "74164", name => "8-Bit Parallel-Out Serial Shift Register" },
    { id => "74165", name => "8-Bit Serial Shift Register (Parallel Load)" },
    { id => "74166", name => "Synchronous 8-Bit Shift Register" },
    { id => "74173", name => "Quad D-Type Register (3-State Outputs)" },
    { id => "74174", name => "Hex D-Type Flip-Flop with Clear" },
    { id => "74175", name => "Quad D-Type Flip-Flop with Clear" },
    { id => "74181", name => "4-Bit Arithmetic Logic Unit (ALU) and Function Generator" },
    { id => "74190", name => "Presettable BCD Up/Down Counter" },
    { id => "74191", name => "Presettable 4-Bit Binary Up/Down Counter" },
    { id => "74192", name => "Presettable BCD Up/Down Counter (Dual Clock)" },
    { id => "74193", name => "Presettable 4-Bit Binary Up/Down Counter (Dual Clock)" },
    { id => "74194", name => "4-Bit Bidirectional Universal Shift Register" },
    { id => "74240", name => "Octal Buffer/Line Driver (Inverting 3-State)" },
    { id => "74241", name => "Octal Buffer/Line Driver (Non-Inverting 3-State Variant)" },
    { id => "74244", name => "Octal Buffer/Line Driver (Non-Inverting 3-State)" },
    { id => "74245", name => "Octal Bidirectional Bus Transceiver (3-State)" },
    { id => "74247", name => "BCD to 7-Segment Decoder/Driver (Open Collector, 0-9 variants)" },
    { id => "74251", name => "8-Line to 1-Line Data Selector/Multiplexer (3-State)" },
    { id => "74257", name => "Quad 2-Line to 1-Line Multiplexer (3-State)" },
    { id => "74273", name => "Octal D-Type Flip-Flop with Master Reset" },
    { id => "74367", name => "Hex Bus Driver (3-State)" },
    { id => "74373", name => "Octal D-Type Transparent Latch (3-State)" },
    { id => "74374", name => "Octal D-Type Edge-Triggered Flip-Flop (3-State)" },
    { id => "74393", name => "Dual 4-Bit Binary Ripple Counter" },
    { id => "74541", name => "Octal Buffer/Line Driver (3-State, Streamlined Pinout)" },
    { id => "74573", name => "Octal D-Type Transparent Latch (3-State, Streamlined Pinout)" },
    { id => "74595", name => "8-Bit Shift Register with Output Latches (Tri-State)" },
    { id => "74688", name => "8-Bit Identity Comparator" },
    { id => "74902", name => "Hex Non-Inverting Buffer" },
    { id => "74266", name => "Quad 2-Input XNOR Gate (Open Collector)" },
);

# Main Application Window
my $window = Gtk3::Window->new('toplevel');
$window->set_title("7400 Logic IC Database");
$window->set_default_size(550, 450);
$window->set_border_width(10);
$window->signal_connect(destroy => sub { Gtk3->main_quit });

# Layout Container
my $vbox = Gtk3::Box->new('vertical', 6);
$window->add($vbox);

# Interactive Search Entry UI Elements
my $search_label = Gtk3::Label->new("Filter components (Type a 7400 IC number or keywords):");
$search_label->set_alignment(0, 0.5);
$vbox->pack_start($search_label, FALSE, FALSE, 0);

my $search_entry = Gtk3::Entry->new();
$vbox->pack_start($search_entry, FALSE, FALSE, 0);

# Build Underlying Data Stores
my $liststore = Gtk3::ListStore->new('Glib::String', 'Glib::String');
my $filter_model = Gtk3::TreeModelFilter->new($liststore);
$filter_model->set_visible_func(\&filter_rows, $search_entry);

# Build the Grid Display
my $treeview = Gtk3::TreeView->new_with_model($filter_model);
$treeview->set_rules_hint(TRUE);

# Layout Data Columns
my $renderer_id = Gtk3::CellRendererText->new();
my $col_id = Gtk3::TreeViewColumn->new_with_attributes("IC Variant", $renderer_id, 'text' => 0);
$col_id->set_min_width(90);
$treeview->append_column($col_id);

my $renderer_name = Gtk3::CellRendererText->new();
my $col_name = Gtk3::TreeViewColumn->new_with_attributes("Functional Description", $renderer_name, 'text' => 1);
$treeview->append_column($col_name);

# View Scroll Window Wrapper
my $scrolled_window = Gtk3::ScrolledWindow->new();
$scrolled_window->set_policy('automatic', 'automatic');
$scrolled_window->add($treeview);
$vbox->pack_start($scrolled_window, TRUE, TRUE, 0);

# Handle keystrokes on the fly
$search_entry->signal_connect(changed => sub {
    $filter_model->refilter();
});

# Initialize structural memory model
populate_store($liststore, \@ttl_database);

# Fire GUI
$window->show_all();
Gtk3->main();

# Core App Operations
sub populate_store {
    my ($store, $data) = @_;
    foreach my $ic (@$data) {
        my $iter = $store->append();
        $store->set($iter, 0 => $ic->{id}, 1 => $ic->{name});
    }
}

sub filter_rows {
    my ($model, $iter, $entry) = @_;
    my $search_text = lc($entry->get_text());
    
    return TRUE if $search_text eq '';

    my $ic_id   = lc($model->get_value($iter, 0));
    my $ic_name = lc($model->get_value($iter, 1));

if (index($ic_id, $search_text) != -1 || index($ic_name, $search_text) != -1) {return TRUE;}return FALSE;}


