#!/usr/bin/perl
use strict;
use warnings;
use Glib qw(TRUE FALSE);
use Gtk3 -init;

# Comprehensive database of standard 4000 & 4500-series CMOS ICs
my @cmos_database = (
    { id => "4000", name => "Dual 3-Input NOR Gate + Inverter" },
    { id => "4001", name => "Quad 2-Input NOR Gate" },
    { id => "4002", name => "Dual 4-Input NOR Gate" },
    { id => "4006", name => "18-Stage Static Shift Register" },
    { id => "4007", name => "Dual Complementary Pair Plus Inverter" },
    { id => "4008", name => "4-Bit Binary Full Adder" },
    { id => "4009", name => "Hex Inverting Buffer/Converter (Obsolete, use 4049)" },
    { id => "4010", name => "Hex Non-Inverting Buffer/Converter (Obsolete, use 4050)" },
    { id => "4011", name => "Quad 2-Input NAND Gate" },
    { id => "4012", name => "Dual 4-Input NAND Gate" },
    { id => "4013", name => "Dual D-Type Flip-Flop (With Set/Reset)" },
    { id => "4014", name => "8-Stage Static Shift Register (Synchronous Parallel Input)" },
    { id => "4015", name => "Dual 4-Stage Static Shift Register (Serial In / Parallel Out)" },
    { id => "4016", name => "Quad Bilateral Analog Switch (Low Performance, use 4066)" },
    { id => "4017", name => "Decade Counter / Divider (5-Stage Johnson Counter)" },
    { id => "4018", name => "Presettable Divide-by-N Counter" },
    { id => "4019", name => "Quad And-Or Select Gate" },
    { id => "4020", name => "14-Stage Ripple-Carry Binary Counter" },
    { id => "4021", name => "8-Stage Static Shift Register (Asynchronous Parallel Input)" },
    { id => "4022", name => "Octal Counter / Divider (4-Stage Johnson Counter)" },
    { id => "4023", name => "Triple 3-Input NAND Gate" },
    { id => "4024", name => "7-Stage Ripple-Carry Binary Counter" },
    { id => "4025", name => "Triple 3-Input NOR Gate" },
    { id => "4026", name => "Decade Counter to 7-Segment Decoder" },
    { id => "4027", name => "Dual JK Flip-Flop (With Set/Reset)" },
    { id => "4028", name => "BCD to Decimal (1-of-10) Decoder" },
    { id => "4029", name => "Presettable Up/Down Counter (Binary or BCD)" },
    { id => "4030", name => "Quad 2-Input XOR Gate (Obsolete, use 4070)" },
    { id => "4031", name => "64-Stage Static Shift Register" },
    { id => "4032", name => "Triple Serial Adder" },
    { id => "4033", name => "Decade Counter to 7-Segment Decoder (With Ripple Blanking)" },
    { id => "4034", name => "8-Stage Universal Bidirectional Parallel/Serial Bus Register" },
    { id => "4035", name => "4-Stage Parallel-In / Parallel-Out Shift Register" },
    { id => "4040", name => "12-Stage Ripple-Carry Binary Counter" },
    { id => "4041", name => "Quad True/Complement Buffer" },
    { id => "4042", name => "Quad Clocked D Latch" },
    { id => "4043", name => "Quad NOR R-S Latch with 3-State Outputs" },
    { id => "4044", name => "Quad NAND R-S Latch with 3-State Outputs" },
    { id => "4045", name => "21-Stage Ripple-Carry Binary Counter" },
    { id => "4046", name => "Phase-Locked Loop (PLL) with VCO" },
    { id => "4047", name => "Low-Power Monostable/Astable Multivibrator" },
    { id => "4048", name => "Multifunction Expandable 8-Input Gate (Tri-State)" },
    { id => "4049", name => "Hex Inverting Buffer / Logic Level Converter" },
    { id => "4050", name => "Hex Non-Inverting Buffer / Logic Level Converter" },
    { id => "4051", name => "8-Channel Analog Multiplexer/Demultiplexer" },
    { id => "4052", name => "Dual 4-Channel Analog Multiplexer/Demultiplexer" },
    { id => "4053", name => "Triple 2-Channel Analog Multiplexer/Demultiplexer" },
    { id => "4054", name => "4-Segment Liquid Crystal Display (LCD) Driver" },
    { id => "4055", name => "BCD to 7-Segment Decoder/Driver with 'Display-Frequency' Output" },
    { id => "4056", name => "BCD to 7-Segment Decoder/Driver with Strobed Latch" },
    { id => "4060", name => "14-Stage Ripple Binary Counter / Oscillator" },
    { id => "4063", name => "4-Bit Magnitude Comparator" },
    { id => "4066", name => "Quad Bilateral Analog Switch" },
    { id => "4067", name => "16-Channel Analog Multiplexer/Demultiplexer" },
    { id => "4068", name => "8-Input NAND/AND Gate" },
    { id => "4069", name => "Hex Inverter" },
    { id => "4070", name => "Quad 2-Input XOR Gate" },
    { id => "4071", name => "Quad 2-Input OR Gate" },
    { id => "4072", name => "Dual 4-Input OR Gate" },
    { id => "4073", name => "Triple 3-Input AND Gate" },
    { id => "4075", name => "Triple 3-Input OR Gate" },
    { id => "4076", name => "Quad D-Type Register with 3-State Outputs" },
    { id => "4077", name => "Quad 2-Input XNOR Gate" },
    { id => "4078", name => "8-Input NOR/OR Gate" },
    { id => "4081", name => "Quad 2-Input AND Gate" },
    { id => "4082", name => "Dual 4-Input AND Gate" },
    { id => "4085", name => "Dual 2-Wide 2-Input AND-OR-INVERT Gate" },
    { id => "4086", name => "Expandable 4-Wide 2-Input AND-OR-INVERT Gate" },
    { id => "4089", name => "Binary Rate Multiplier" },
    { id => "4093", name => "Quad 2-Input NAND Schmitt Trigger" },
    { id => "4094", name => "8-Stage Shift-and-Store Bus Register" },
    { id => "4095", name => "Gated J-K Flip-Flop (Non-Inverting inputs)" },
    { id => "4096", name => "Gated J-K Flip-Flop (Inverting and Non-Inverting inputs)" },
    { id => "4097", name => "Differential 8-Channel Analog Multiplexer/Demultiplexer" },
    { id => "4098", name => "Dual Monostable Multivibrator" },
    { id => "4099", name => "8-Bit Addressable Latch" },
    { id => "4106", name => "Hex Inverter with Schmitt Trigger Inputs" },
    { id => "4502", name => "Strobed Hex Inverter / Buffer with 3-State Outputs" },
    { id => "4503", name => "Hex Non-Inverting Buffer with 3-State Outputs" },
    { id => "4504", name => "Hex Voltage Level Shifter (TTL-to-CMOS / CMOS-to-CMOS)" },
    { id => "4505", name => "64-Bit Static RAM (16x4)" },
    { id => "4508", name => "Dual 4-Bit Latch with 3-State Outputs" },
    { id => "4510", name => "Presettable BCD Up/Down Counter" },
    { id => "4511", name => "BCD to 7-Segment Latch/Decoder/Driver" },
    { id => "4512", name => "8-Channel Data Selector with 3-State Output" },
    { id => "4514", name => "1-of-16 Decoder/Demultiplexer (Outputs High on Select)" },
    { id => "4515", name => "1-of-16 Decoder/Demultiplexer (Outputs Low on Select)" },
    { id => "4516", name => "Presettable Binary Up/Down Counter" },
    { id => "4517", name => "Dual 64-Stage Static Shift Register" },
    { id => "4518", name => "Dual BCD Up-Counter" },
    { id => "4520", name => "Dual Binary Up-Counter" },
    { id => "4521", name => "24-Stage Frequency Divider" },
    { id => "4522", name => "Programmable BCD Divide-by-N Counter" },
    { id => "4526", name => "Programmable Binary Divide-by-N Counter" },
    { id => "4527", name => "BCD Rate Multiplier" },
    { id => "4528", name => "Dual Monostable Multivibrator" },
    { id => "4532", name => "8-Bit Priority Encoder" },
    { id => "4538", name => "Dual Precision Monostable Multivibrator" },
    { id => "4541", name => "Programmable Oscillator / Timer" },
    { id => "4543", name => "BCD to 7-Segment Latch/Decoder/Driver for LCD displays" },
    { id => "4555", name => "Dual 1-of-4 Decoder/Demultiplexer (Outputs High on Select)" },
    { id => "4556", name => "Dual 1-of-4 Decoder/Demultiplexer (Outputs Low on Select)" },
    { id => "4584", name => "Hex Schmitt Trigger Inverter" },
    { id => "4585", name => "4-Bit Magnitude Comparator" },
);

# Main Application Window
my $window = Gtk3::Window->new('toplevel');
$window->set_title("CMOS Logic IC Database");
$window->set_default_size(550, 450);
$window->set_border_width(10);
$window->signal_connect(destroy => sub { Gtk3->main_quit });

# Layout Container
my $vbox = Gtk3::Box->new('vertical', 6);
$window->add($vbox);

# Interactive Search Entry UI Elements
my $search_label = Gtk3::Label->new("Filter components (Type an IC number or functional keywords):");
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
populate_store($liststore, \@cmos_database);

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

    if (index($ic_id, $search_text) != -1 || index($ic_name, $search_text) != -1) {
        return TRUE;
    }
    return FALSE;
}

