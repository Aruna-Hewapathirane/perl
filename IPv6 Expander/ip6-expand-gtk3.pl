#!/usr/bin/env perl
use strict;
use warnings;
use feature qw(say);
use Socket qw(inet_pton AF_INET6);
use Gtk3 -init;

# 1. Create the main application window
my $window = Gtk3::Window->new('toplevel');
$window->set_title("System IPv6 Expander");
$window->set_default_size(550, 300);
$window->set_border_width(10);
$window->signal_connect(destroy => sub { Gtk3::main_quit() });

# 2. Set up a scrollable container
my $scrolled_window = Gtk3::ScrolledWindow->new();
$scrolled_window->set_policy('automatic', 'automatic');

# 3. Create a ListStore to hold our data
my $store = Gtk3::ListStore->new('Glib::String');

# 4. Create the TreeView
my $treeview = Gtk3::TreeView->new_with_model($store);

# 5. Add a visible column and enforce a Monospace Font
my $renderer = Gtk3::CellRendererText->new();
$renderer->set(font => "Monospace 10");

my $column = Gtk3::TreeViewColumn->new_with_attributes(
    "Expanded IPv6 Addresses", $renderer, text => 0
);
$treeview->append_column($column);

# 6. Gather data and populate the GUI
my @ip6s = split /\n/, `ip a | grep inet6`;

for (@ip6s) {
    # Match anything that looks like an IPv6 address before the subnet slash '/'
    # This extracts only valid hex/colon blocks and ignores words like 'inet6'
    if (my ($addr) = $_ =~ /([a-fA-F0-9:]+)\/\d+/) {
        
        eval {
            my $packed = inet_pton(AF_INET6, $addr);
            if ($packed) {
                $addr = join ":", unpack "H4" x 8, $packed;
                
                my $iter = $store->append();
                $store->set($iter, 0, $addr);
            }
        };
    }
}

# 7. Assemble and display
$scrolled_window->add($treeview);
$window->add($scrolled_window);
$window->show_all();

Gtk3::main();

