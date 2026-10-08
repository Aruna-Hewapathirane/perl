#!/usr/bin/env perl
#
# A small tabbed web browser in Perl, using Gtk3 and WebKit2 (the engine
# behind GNOME Web / Safari).
#
# Debian/Ubuntu:  sudo apt install libgtk3-perl libglib-object-introspection-perl \
#                                  gir1.2-webkit2-4.1
#                 (on older releases use gir1.2-webkit2-4.0)
# Fedora:         sudo dnf install perl-Gtk3 perl-Glib-Object-Introspection webkit2gtk4.1
#
# Run:            perl plbrowser.pl [url]
#
# Shortcuts: Ctrl+T new tab, Ctrl+W close tab, Ctrl+L focus address bar,
#            Alt+Left / Alt+Right back / forward, F5 or Ctrl+R reload.

use strict;
use warnings;
use utf8;

use Encode qw(encode_utf8);
use Gtk3 '-init';
use Glib::Object::Introspection;

# WebKit2 has no hand-written Perl binding, so load it through introspection.
# 4.1 is the libsoup3 build, 4.0 the older one; try both.
{
    my $loaded;
    for my $version ('4.1', '4.0') {
        if (eval {
                Glib::Object::Introspection->setup(
                    basename => 'WebKit2',
                    version  => $version,
                    package  => 'WebKit2',
                );
                1;
            })
        {
            $loaded = $version;
            last;
        }
    }
    die "Could not load the WebKit2 typelib (install gir1.2-webkit2-4.1).\n"
        unless $loaded;
}

my $APP_NAME   = 'PlBrowser';
my $HOME_URL   = 'https://duckduckgo.com';
my $SEARCH_URL = 'https://duckduckgo.com/?q=%s';

# ---------------------------------------------------------------- URL handling

# Turn whatever was typed in the address bar into a URL. Anything with a scheme
# is used as-is, host-like text gets a scheme added, everything else is searched.
sub url_from_input {
    my ($text) = @_;
    $text //= '';
    $text =~ s/^\s+|\s+$//g;

    return $HOME_URL unless length $text;
    return $text if $text =~ m{^[a-z][a-z0-9+.\-]*://}i
                 or $text =~ /^(?:about|file|data):/i;

    if ($text !~ /\s/ and ($text =~ /\./ or $text =~ /^localhost/i)) {
        # local addresses are normally plain http
        return ($text =~ /^(?:localhost|\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?(?:\/|$)/i)
            ? "http://$text"
            : "https://$text";
    }

    my $query = encode_utf8($text);
    $query =~ s/([^A-Za-z0-9\-._~])/sprintf('%%%02X', ord $1)/ge;
    return sprintf($SEARCH_URL, $query);
}

# Does a Gdk modifier state contain the given mask (e.g. 'control-mask')?
# Flags can come back as an array of names or as a Glib::Flags object.
sub has_mod {
    my ($state, $mask) = @_;
    return 0 unless defined $state;
    if (ref($state) eq 'ARRAY') {
        return (grep { $_ eq $mask } @$state) ? 1 : 0;
    }
    my $result = eval { $state >= $mask };
    return $result ? 1 : 0;
}

# ------------------------------------------------------------------- main window

my $window = Gtk3::Window->new('toplevel');
$window->set_default_size(1200, 800);
$window->set_title($APP_NAME);
$window->signal_connect(destroy => sub { Gtk3->main_quit });

my $vbox = Gtk3::Box->new('vertical', 0);
$window->add($vbox);

# toolbar: back, forward, reload, home, address bar, new tab
my $toolbar = Gtk3::Box->new('horizontal', 4);
$toolbar->set_border_width(4);
$vbox->pack_start($toolbar, 0, 0, 0);

my $back_btn    = Gtk3::Button->new_from_icon_name('go-previous', 'button');
my $forward_btn = Gtk3::Button->new_from_icon_name('go-next',     'button');
my $reload_btn  = Gtk3::Button->new_from_icon_name('view-refresh', 'button');
my $home_btn    = Gtk3::Button->new_from_icon_name('go-home',      'button');
my $newtab_btn  = Gtk3::Button->new_from_icon_name('tab-new',      'button');

$back_btn->set_tooltip_text('Back (Alt+Left)');
$forward_btn->set_tooltip_text('Forward (Alt+Right)');
$reload_btn->set_tooltip_text('Reload (F5)');
$home_btn->set_tooltip_text('Home');
$newtab_btn->set_tooltip_text('New tab (Ctrl+T)');

my $address = Gtk3::Entry->new;
$address->set_placeholder_text('Search or enter address');

$toolbar->pack_start($_, 0, 0, 0)
    for ($back_btn, $forward_btn, $reload_btn, $home_btn);
$toolbar->pack_start($address, 1, 1, 0);
$toolbar->pack_start($newtab_btn, 0, 0, 0);

# thin load-progress bar, only visible while a page is loading
my $progress = Gtk3::ProgressBar->new;
$vbox->pack_start($progress, 0, 0, 0);

# tabs
my $notebook = Gtk3::Notebook->new;
$notebook->set_scrollable(1);
$vbox->pack_start($notebook, 1, 1, 0);

# ----------------------------------------------------------------------- helpers

sub current_view {
    my $n = $notebook->get_current_page;
    return $n >= 0 ? $notebook->get_nth_page($n) : undef;
}

sub is_current {
    my ($view) = @_;
    my $n = $notebook->page_num($view);
    return $n >= 0 && $n == $notebook->get_current_page;
}

# Make the toolbar and title bar reflect the given tab.
sub sync_ui {
    my ($view) = @_;
    return unless $view;

    $address->set_text($view->get_uri // '');
    $address->set_position(0);

    my $title = $view->get_title // '';
    $window->set_title(length $title ? "$title - $APP_NAME" : $APP_NAME);

    $back_btn->set_sensitive($view->can_go_back ? 1 : 0);
    $forward_btn->set_sensitive($view->can_go_forward ? 1 : 0);

    my $fraction = $view->get_estimated_load_progress;
    $progress->set_fraction($fraction);
    $progress->set_visible($fraction > 0 && $fraction < 1 ? 1 : 0);
}

sub make_tab_label {
    my ($view) = @_;

    my $box   = Gtk3::Box->new('horizontal', 4);
    my $label = Gtk3::Label->new('New Tab');
    $label->set_ellipsize('end');
    $label->set_max_width_chars(20);

    my $close = Gtk3::Button->new_from_icon_name('window-close', 'menu');
    $close->set_relief('none');
    $close->signal_connect(clicked => sub { close_view($view) });

    $box->pack_start($label, 1, 1, 0);
    $box->pack_start($close, 0, 0, 0);
    $box->show_all;
    return ($box, $label);
}

sub close_view {
    my ($view) = @_;
    if ($notebook->get_n_pages <= 1) {   # closing the last tab quits
        Gtk3->main_quit;
        return;
    }
    my $n = $notebook->page_num($view);
    $notebook->remove_page($n) if $n >= 0;
}

# Create a tab. Pass url => '...' to load something, or related => $view when
# WebKit asks for a new window (target=_blank links, pop-ups).
sub add_tab {
    my (%opt) = @_;

    my $view = $opt{related}
        ? WebKit2::WebView->new_with_related_view($opt{related})
        : WebKit2::WebView->new;

    my ($tab_box, $tab_label) = make_tab_label($view);
    my $index = $notebook->append_page($view, $tab_box);
    $notebook->set_tab_reorderable($view, 1);
    $view->show;
    $notebook->set_current_page($index);

    $view->signal_connect('notify::title' => sub {
        my $title = $view->get_title // '';
        $tab_label->set_text(length $title ? $title : 'New Tab');
        $tab_label->set_tooltip_text($title);
        sync_ui($view) if is_current($view);
    });
    $view->signal_connect('notify::uri' => sub {
        sync_ui($view) if is_current($view);
    });
    $view->signal_connect('notify::estimated-load-progress' => sub {
        sync_ui($view) if is_current($view);
    });
    $view->signal_connect('load-changed' => sub {
        sync_ui($view) if is_current($view);
    });
    $view->signal_connect('create' => sub {
        my ($source_view) = @_;
        return add_tab(related => $source_view);
    });

    $view->load_uri($opt{url}) if defined $opt{url};
    return $view;
}

# ------------------------------------------------------------------- wiring up

$notebook->signal_connect('switch-page' => sub {
    my (undef, $page) = @_;     # the page is not "current" yet inside this signal
    sync_ui($page);
});

$back_btn->signal_connect(clicked => sub    { my $v = current_view(); $v->go_back    if $v });
$forward_btn->signal_connect(clicked => sub { my $v = current_view(); $v->go_forward if $v });
$reload_btn->signal_connect(clicked => sub  { my $v = current_view(); $v->reload     if $v });
$home_btn->signal_connect(clicked => sub    { my $v = current_view(); $v->load_uri($HOME_URL) if $v });
$newtab_btn->signal_connect(clicked => sub  { add_tab(url => $HOME_URL) });

$address->signal_connect(activate => sub {
    my $v = current_view() or return;
    $v->load_uri(url_from_input($address->get_text));
    $v->grab_focus;
});

$window->signal_connect('key-press-event' => sub {
    my (undef, $event) = @_;
    my $key  = $event->keyval;
    my $ctrl = has_mod($event->state, 'control-mask');
    my $alt  = has_mod($event->state, 'mod1-mask');
    my $char = ($key >= 32 && $key < 127) ? lc chr($key) : '';
    my $view = current_view();

    if ($ctrl && $char eq 't') { add_tab(url => $HOME_URL); return 1 }
    if ($ctrl && $char eq 'w') { close_view($view) if $view; return 1 }
    if ($ctrl && $char eq 'l') { $address->grab_focus; $address->select_region(0, -1); return 1 }
    if ($ctrl && $char eq 'r') { $view->reload if $view; return 1 }
    if ($key == 0xffc2)        { $view->reload if $view; return 1 }       # F5
    if ($alt && $key == 0xff51) { $view->go_back    if $view; return 1 }  # Alt+Left
    if ($alt && $key == 0xff53) { $view->go_forward if $view; return 1 }  # Alt+Right
    return 0;
});

# ------------------------------------------------------------------------ start

$window->show_all;
$progress->set_visible(0);   # show_all revealed it; hide until a load starts

add_tab(url => defined $ARGV[0] ? url_from_input($ARGV[0]) : $HOME_URL);

Gtk3->main;
