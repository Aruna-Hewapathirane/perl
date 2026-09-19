#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Gtk3 '-init';

# 1. Official TIOBE Index Global Programming Language Rankings
my @languages_data = (
    { rank => 1,  name => "Python",         share => "17.76%", trend => "Steady Leader" },
    { rank => 2,  name => "C",              share => "9.40%",  trend => "Stable" },
    { rank => 3,  name => "C++",            share => "8.67%",  trend => "Rising" },
    { rank => 4,  name => "Java",           share => "7.54%",  trend => "Declining" },
    { rank => 5,  name => "C#",             share => "4.85%",  trend => "Stable" },
    { rank => 6,  name => "JavaScript",     share => "2.92%",  trend => "Ubiquitous Web" },
    { rank => 7,  name => "Visual Basic",   share => "2.30%",  trend => "Stable Legacy" },
    { rank => 8,  name => "SQL",            share => "2.16%",  trend => "Strong Core" },
    { rank => 9,  name => "R",              share => "1.69%",  trend => "Data Science" },
    { rank => 10, name => "Rust",           share => "1.45%",  trend => "Fast Growing" },
    { rank => 11, name => "Go",             share => "1.28%",  trend => "Cloud Native" },
    { rank => 12, name => "Swift",          share => "1.15%",  trend => "Apple Native" },
    { rank => 13, name => "Delphi/Pascal",  share => "1.10%",  trend => "Legacy Enterprise" },
    { rank => 14, name => "PHP",            share => "1.04%",  trend => "Web Infrastructure" },
    { rank => 15, name => "MATLAB",         share => "0.95%",  trend => "Academic Shift" },
    { rank => 16, name => "Fortran",        share => "0.88%",  trend => "HPC Niche" },
    { rank => 17, name => "Scratch",        share => "0.82%",  trend => "Education" },
    { rank => 18, name => "Kotlin",         share => "0.79%",  trend => "Android Core" },
    { rank => 19, name => "Julia",          share => "0.72%",  trend => "Approaching Top 20" },
    { rank => 20, name => "Objective-C",    share => "0.68%",  trend => "Renewed Strength" },
    { rank => 26, name => "Perl",           share => "0.13%",  trend => "System Scripting" },
);

# 2. Main Windows Setup
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Programming Language Market Share Index');
$window->set_default_size(550, 610);
$window->set_position('center');
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

# 3. ListStore Definition: Rank(Int), Name(String), Share(String), Description(String)
my $model = Gtk3::ListStore->new('Glib::Int', 'Glib::String', 'Glib::String', 'Glib::String');

# Load index elements cleanly
for my $lang (sort { $a->{rank} <=> $b->{rank} } @languages_data) {
    my $iter = $model->append();
    $model->set($iter, 
        0 => $lang->{rank}, 
        1 => $lang->{name}, 
        2 => $lang->{share}, 
        3 => $lang->{trend}
    );
}

# 4. View Architecture & Sort Columns configuration
my $treeview = Gtk3::TreeView->new_with_model($model);

# Column 1: Current Rank
my $col_rank = Gtk3::TreeViewColumn->new_with_attributes(
    "Rank", Gtk3::CellRendererText->new(), text => 0
);
$col_rank->set_sort_column_id(0);
$treeview->append_column($col_rank);

# Column 2: Language Identity
my $col_name = Gtk3::TreeViewColumn->new_with_attributes(
    "Programming Language", Gtk3::CellRendererText->new(), text => 1
);
$col_name->set_sort_column_id(1);
$treeview->append_column($col_name);

# Column 3: Market Rating Share
my $col_share = Gtk3::TreeViewColumn->new_with_attributes(
    "TIOBE Share", Gtk3::CellRendererText->new(), text => 2
);
$col_share->set_sort_column_id(2);
$treeview->append_column($col_share);

# Column 4: Market Dynamics
my $col_trend = Gtk3::TreeViewColumn->new_with_attributes(
    "Market Context", Gtk3::CellRendererText->new(), text => 3
);
$col_trend->set_sort_column_id(3);
$treeview->append_column($col_trend);

# 5. UI Wrapping and Packing
my $scrolled_window = Gtk3::ScrolledWindow->new();
$scrolled_window->set_policy('automatic', 'automatic');
$scrolled_window->add($treeview);

my $vbox = Gtk3::Box->new('vertical', 6);
$vbox->set_border_width(12);

my $header_lbl = Gtk3::Label->new("<b>Global Language Metrics Index Dashboard</b>");
$header_lbl->set_use_markup(1);

$vbox->pack_start($header_lbl, 0, 0, 4);
$vbox->pack_start($scrolled_window, 1, 1, 0);

$window->add($vbox);
$window->show_all();

Gtk3::main();

