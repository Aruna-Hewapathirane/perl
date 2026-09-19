#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Gtk3 '-init';

# 1. Main Window Layout Setup
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Perl 5 Core Language Commands');
$window->set_default_size(700, 900);
$window->signal_connect(destroy => sub { Gtk3::main_quit; });

my $vbox = Gtk3::Box->new('vertical', 10);
$window->add($vbox);

# 2. Scroll Pane Container for Tree Compatibility
my $scroll = Gtk3::ScrolledWindow->new();
$scroll->set_policy('automatic', 'automatic');
$vbox->pack_start($scroll, 1, 1, 0);

# 3. Model Setup: TreeStore supports Hierarchical data (Parent -> Child rows)
# Columns: 0 = Command Name/Group, 1 = Description/Syntax
my $model = Gtk3::TreeStore->new('Glib::String', 'Glib::String');

# =========================================================================
# 4. Data Insertion - Mapping the Comprehensive Breakdown to Tree Nodes
# =========================================================================

# --- GROUP 1: Variables & Scope ---
my $p1 = $model->append(undef); # 'undef' sets this as a top-level parent node
$model->set($p1, 0 => "1. Variables & Scope", 1 => "How data is typed and scoped");

$model->set($model->append($p1), 0 => 'my', 1 => 'Declares a lexically scoped local variable (e.g., my $x = 10;)');
$model->set($model->append($p1), 0 => '$scalar', 1 => 'Holds a single value (string, number, or object reference)');
$model->set($model->append($p1), 0 => '@array', 1 => 'Holds an ordered list of values (indexed numerically)');
$model->set($model->append($p1), 0 => '%hash', 1 => 'Holds unordered key/value property pairs');
$model->set($model->append($p1), 0 => '\\', 1 => 'Reference operator. Creates a reference pointer to a data variable');

# --- GROUP 2: Control Flow & Loops ---
my $p2 = $model->append(undef);
$model->set($p2, 0 => "2. Control Flow & Loops", 1 => "Directs conditional execution and logic paths");

$model->set($model->append($p2), 0 => 'if / elsif / else', 1 => 'Standard conditional branches evaluated on truth');
$model->set($model->append($p2), 0 => 'unless', 1 => 'Conditional block that executes only if the criteria is FALSE');
$model->set($model->append($p2), 0 => 'foreach', 1 => 'Iterates directly over elements in an array or a list');
$model->set($model->append($p2), 0 => 'for', 1 => 'Traditional 3-part C-style mechanical looping mechanism');
$model->set($model->append($p2), 0 => 'while', 1 => 'Continuously loops through a block as long as a condition remains true');

# --- GROUP 3: Array & List Manipulation ---
my $p3 = $model->append(undef);
$model->set($p3, 0 => "3. Array & List Manipulation", 1 => "Modifies indices and values inside list groups");

$model->set($model->append($p3), 0 => 'push', 1 => 'Appends one or more items to the end of an array');
$model->set($model->append($p3), 0 => 'pop', 1 => 'Removes and returns the absolute last element of an array');
$model->set($model->append($p3), 0 => 'shift', 1 => 'Removes and returns the absolute first element of an array');
$model->set($model->append($p3), 0 => 'unshift', 1 => 'Prepends one or more items onto the front of an array');
$model->set($model->append($p3), 0 => 'split', 1 => 'Breaks a string structure down into an array using a regex delimiter');
$model->set($model->append($p3), 0 => 'join', 1 => 'Glues array elements together into one flat string with a glue character');
$model->set($model->append($p3), 0 => '$#array', 1 => 'Returns the index position of the absolute last element of the array');

# --- GROUP 4: String & Text Processing ---
my $p4 = $model->append(undef);
$model->set($p4, 0 => "4. String & Text Processing", 1 => "Native utilities optimized for manipulating text fields");

$model->set($model->append($p4), 0 => 'print', 1 => 'Outputs textual sequences directly to standard output / command line');
$model->set($model->append($p4), 0 => 'sprintf', 1 => 'Returns a structurally formatted string layout mapping custom formatting flags');
$model->set($model->append($p4), 0 => 'length', 1 => 'Evaluates and returns total characters inside target scalar string');
$model->set($model->append($p4), 0 => 'substr', 1 => 'Extracts or replaces a precise segment from a text scalar string');

# --- GROUP 5: Code Structure & Subroutines ---
my $p5 = $model->append(undef);
$model->set($p5, 0 => "5. Code Structure & Subs", 1 => "Encapsulates structural tasks and event routines");

$model->set($model->append($p5), 0 => 'sub name { ... }', 1 => 'Defines a named, reuseable code execution routine (subroutine)');
$model->set($model->append($p5), 0 => 'sub { ... }', 1 => 'Anonymous inline subroutine. Extensively used for GTK signal handlers');
$model->set($model->append($p5), 0 => 'return', 1 => 'Breaks operation loop inside subroutine to instantly hand back scalar variables');
$model->set($model->append($p5), 0 => 'shift (inside sub)', 1 => 'Implicitly pulls the first parameter variable off the default context array @_');

# --- GROUP 6: Pragmas ---
my $p6 = $model->append(undef);
$model->set($p6, 0 => "6. Pragmas (Directives)", 1 => "Flags enforcement parameters to the compiler framework");

$model->set($model->append($p6), 0 => 'use strict;', 1 => 'Blocks execution if variables lack explicit variable scoping rules (stops typos)');
$model->set($model->append($p6), 0 => 'use warnings;', 1 => 'Instructs engine to report suspicious non-breaking syntax logic flaws');
$model->set($model->append($p6), 0 => 'use utf8;', 1 => 'Allows source file script parsing to recognize native international layout glyphs');

# =========================================================================
# 5. View Setup (TreeView Rendering)
# =========================================================================
my $treeview = Gtk3::TreeView->new_with_model($model);
$scroll->add($treeview);

# Column 1 - Command Name / Node Title
my $renderer1 = Gtk3::CellRendererText->new();
$renderer1->set('weight' => 700); # Makes parent headers and commands distinct
my $col1 = Gtk3::TreeViewColumn->new_with_attributes("Perl Command / Category", $renderer1, text => 0);
$col1->set_min_width(220);
$treeview->append_column($col1);

# Column 2 - Details and Description
my $renderer2 = Gtk3::CellRendererText->new();
my $col2 = Gtk3::TreeViewColumn->new_with_attributes("Syntax & Behavior Description", $renderer2, text => 1);
$treeview->append_column($col2);

# Automatically expand all parent categorizations out on initial presentation
$treeview->expand_all();

# Show Window loop
$window->show_all();
Gtk3::main();

