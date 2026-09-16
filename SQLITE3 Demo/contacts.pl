#!/usr/bin/env perl
use strict;
use warnings;
use Glib qw(TRUE FALSE);
use Gtk3 -init;
use DBI;

# --- 1. Database Setup ---
my $db_file = "contacts.db";
my $dbh     = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
    RaiseError => 1,
    AutoCommit => 1,
    PrintError => 0,
}) or die $DBI::errstr;

$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT
)
SQL

# --- 2. Main Window Configuration ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title("GTK3 Contact Manager");
$window->set_default_size(650, 450);
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

# Main Vertical Layout Box
my $vbox = Gtk3::Box->new('vertical', 10);
$vbox->set_border_width(10);
$window->add($vbox);

# --- 3. Form Layout (Grid) ---
my $grid = Gtk3::Grid->new();
$grid->set_row_spacing(6);
$grid->set_column_spacing(10);
$vbox->pack_start($grid, FALSE, FALSE, 0);

# Form Fields
my $entry_id    = Gtk3::Entry->new(); $entry_id->set_sensitive(FALSE); # Read-only
my $entry_name  = Gtk3::Entry->new();
my $entry_phone = Gtk3::Entry->new();
my $entry_email = Gtk3::Entry->new();

# Attach elements to Grid: (widget, left, top, width, height)
$grid->attach(Gtk3::Label->new("Selected ID:"), 0, 0, 1, 1);
$grid->attach($entry_id,                        1, 0, 1, 1);

$grid->attach(Gtk3::Label->new("Full Name *:"), 0, 1, 1, 1);
$grid->attach($entry_name,                      1, 1, 1, 1);
$entry_name->set_hexpand(TRUE);

$grid->attach(Gtk3::Label->new("Phone:"),       0, 2, 1, 1);
$grid->attach($entry_phone,                     1, 2, 1, 1);

$grid->attach(Gtk3::Label->new("Email:"),       0, 3, 1, 1);
$grid->attach($entry_email,                     1, 3, 1, 1);

# --- 4. Action Buttons ---
my $btn_box = Gtk3::ButtonBox->new('horizontal');
$btn_box->set_layout('start');
$btn_box->set_spacing(6);
$vbox->pack_start($btn_box, FALSE, FALSE, 0);

my $btn_save   = Gtk3::Button->new_with_label("Save Contact");
my $btn_delete = Gtk3::Button->new_with_label("Delete Selected");
my $btn_clear  = Gtk3::Button->new_with_label("Clear Form");

$btn_box->add($btn_save);
$btn_box->add($btn_delete);
$btn_box->add($btn_clear);

# --- 5. Data List View (Gtk3::TreeView) ---
# Define columns: 0=ID (int), 1=Name (string), 2=Phone (string), 3=Email (string)
my $list_store = Gtk3::ListStore->new('Glib::Int', 'Glib::String', 'Glib::String', 'Glib::String');

my $tree_view = Gtk3::TreeView->new_with_model($list_store);
$vbox->pack_start($tree_view, TRUE, TRUE, 0);

# Append structural column lookups to the visual TreeView UI
my @headers = ("ID", "Name", "Phone", "Email");
for my $i (0 .. $#headers) {
    my $renderer = Gtk3::CellRendererText->new();
    my $column   = Gtk3::TreeViewColumn->new_with_attributes($headers[$i], $renderer, text => $i);
    $tree_view->append_column($column);
}

# --- 6. Event Callbacks & Signal Intercepts ---
$btn_save->signal_connect(clicked   => \&on_save_clicked);
$btn_delete->signal_connect(clicked => \&on_delete_clicked);
$btn_clear->signal_connect(clicked  => \&clear_form);
$tree_view->signal_connect('row-activated' => \&on_row_double_clicked);

# Primary runtime setup loading
refresh_contact_list();
$window->show_all();
Gtk3::main();

# --- 7. Subroutine Logics ---

sub refresh_contact_list {
    $list_store->clear();
    
    my $sth = $dbh->prepare("SELECT id, name, phone, email FROM contacts ORDER BY name ASC");
    $sth->execute();
    
    while (my $row = $sth->fetchrow_hashref) {
        my $iter = $list_store->append();
        $list_store->set($iter,
            0 => $row->{id},
            1 => $row->{name},
            2 => $row->{phone} // '',
            3 => $row->{email} // ''
        );
    }
}

sub on_save_clicked {
    my $name  = $entry_name->get_text();
    my $phone = $entry_phone->get_text();
    my $email = $entry_email->get_text();
    my $id    = $entry_id->get_text();

    if ($name =~ /^\s*$/) {
        show_message("Error", "Name field is required!", 'error');
        return;
    }

    if ($id ne "") {
        my $sth = $dbh->prepare("UPDATE contacts SET name = ?, phone = ?, email = ? WHERE id = ?");
        $sth->execute($name, $phone, $email, $id);
    } else {
        my $sth = $dbh->prepare("INSERT INTO contacts (name, phone, email) VALUES (?, ?, ?)");
        $sth->execute($name, $phone, $email);
    }

    clear_form();
    refresh_contact_list();
}

sub on_delete_clicked {
    my $id = $entry_id->get_text();
    if ($id eq "") {
        show_message("Warning", "Please select a contact from the list first (Double-click item).", 'warning');
        return;
    }

    my $sth = $dbh->prepare("DELETE FROM contacts WHERE id = ?");
    $sth->execute($id);
    
    clear_form();
    refresh_contact_list();
}

sub on_row_double_clicked {
    my ($view, $path, $column) = @_;
    my $model = $view->get_model();
    my $iter  = $model->get_iter($path);
    
    # Extract data strings directly out from active selected store variables
    my $id    = $model->get($iter, 0);
    my $name  = $model->get($iter, 1);
    my $phone = $model->get($iter, 2);
    my $email = $model->get($iter, 3);
    
    # Populate fields
    $entry_id->set_text($id);
    $entry_name->set_text($name);
    $entry_phone->set_text($phone);
    $entry_email->set_text($email);
}

sub clear_form {
    $entry_id->set_text("");
    $entry_name->set_text("");
    $entry_phone->set_text("");
    $entry_email->set_text("");
}

sub show_message {
    my ($title, $text, $type) = @_;
    my $dialog = Gtk3::MessageDialog->new(
        $window,
        'destroy-with-parent',
        $type,
        'ok',
        $text
    );
    $dialog->set_title($title);
    $dialog->run();
    $dialog->destroy();
}

