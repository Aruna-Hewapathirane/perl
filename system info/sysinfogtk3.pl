#!/usr/bin/perl
use strict;
use warnings;
use Gtk3 -init;

# 1. Main Window Setup
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Debian System Information");
$window->set_default_size(950, 580);
$window->signal_connect(destroy => sub { Gtk3::main_quit() });

# 2. Main Layout Containers
my $main_box = Gtk3::Box->new('horizontal', 15);
$main_box->set_border_width(12);
$window->add($main_box);

# Left container: Sidebar grid to align our structural elements precisely
my $sidebar_grid = Gtk3::Grid->new();
$sidebar_grid->set_row_spacing(6); 
$main_box->pack_start($sidebar_grid, 0, 0, 0);

# Right container for output text frame
my $content_box = Gtk3::Box->new('vertical', 0);
$main_box->pack_start($content_box, 1, 1, 0);

my $scrolled_window = Gtk3::ScrolledWindow->new();
$scrolled_window->set_policy('automatic', 'automatic');
$content_box->pack_start($scrolled_window, 1, 1, 0);

my $text_view = Gtk3::TextView->new();
$text_view->set_editable(0); 
$text_view->set_monospace(1); 
$scrolled_window->add($text_view);

# 3. Command Action Wrapper
sub run_system_command {
    my ($command) = @_;
    my $output = `$command 2>&1`;
    utf8::decode($output); 
    
    if ($? != 0) {
        $output = "[!] Error executing command: $command\n\n$output";
    } elsif (!$output || $output =~ /^\s*$/) {
        $output = "Command executed successfully but returned no output.";
    }
    
    my $buffer = $text_view->get_buffer();
    $buffer->set_text($output);
}

# 4. Structured Menu Items
my @menu_items = (
    { header => "SYSTEM OVERVIEW" },
    { label => "System Info (uname)",  cmd => "uname -a" },
    { label => "OS-Release",  cmd => "cat /etc/os-release" },

    { label => "System Load (uptime)",  cmd => "uptime" },
    { label => "CPU Info (lscpu)",      cmd => "lscpu" },
    { label => "Memory Usage (free)",   cmd => "free -h" },
    { label => "Sensors Data",          cmd => "sensors" },

    { header => "STORAGE &amp; FILESYSTEMS" },
    { label => "Storage (lsblk)",       cmd => "lsblk -S" },
    { label => "Disk Space (df)",       cmd => "df -h" },

    { header => "HARDWARE &amp; NETWORKING" },
    { label => "USB Busses (lsusb)",    cmd => "lsusb" },
    { label => "PCI Devices (lspci)",    cmd => "lspci" },
    { label => "Network IPs (ip)",      cmd => "ip -br a" },
);

# 5. Build Sidebar Elements Loop
my $first_cmd = undef;
my $row_index = 0;

foreach my $item (@menu_items) {
    if (exists $item->{header}) {
        # Fix: Construct the label explicitly as a non-collapsible text entity
        my $header_label = Gtk3::Label->new("TEST");
        $header_label->set_markup("<b>" . $item->{header} . "</b>");
        
        # Configure layout anchoring properties to ensure text visibility
        $header_label->set_halign('start');
        $header_label->set_valign('center');
        
        if ($row_index > 0) {
            $header_label->set_margin_top(15);
        }
        $header_label->set_margin_bottom(2);
        
        # Attach directly into grid matrix context: (widget, col, row, width, height)
        $sidebar_grid->attach($header_label, 0, $row_index, 1, 1);
        $row_index++;
    } 
    elsif (exists $item->{label}) {
        $first_cmd //= $item->{cmd};

        my $button = Gtk3::Button->new_with_label($item->{label});
        
        # Fix: Use non-deprecated standard alignments to force text grouping leftward
        $button->set_halign('fill');
        if (my $child = $button->get_child()) {
            $child->set_halign('start');
        }
        
        $button->signal_connect(clicked => sub {
            run_system_command($item->{cmd});
        });
        
        $sidebar_grid->attach($button, 0, $row_index, 1, 1);
        $row_index++;
    }
}

# 6. Add an elastic spacer block that expands downward, pulling all grid rows tight up top
my $end_spacer = Gtk3::Label->new("");
$end_spacer->set_vexpand(1);
$sidebar_grid->attach($end_spacer, 0, $row_index, 1, 1);

# Pre-load the first tool into view on startup
if (defined $first_cmd) {
    run_system_command($first_cmd);
}

$window->show_all();
Gtk3::main();

