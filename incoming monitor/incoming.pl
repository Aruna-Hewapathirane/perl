#!/usr/bin/perl
# GTK3 incoming-connection monitor.
# Run as your NORMAL user: perl incoming_monitor.pl
# Only tcpdump is elevated (via pkexec, falling back to sudo).
#
# Deps (Debian/Ubuntu): sudo apt install libgtk3-perl tcpdump policykit-1 libnotify-bin
# Deps (Fedora):        sudo dnf install perl-Gtk3 tcpdump polkit libnotify
use strict;
use warnings;
use Gtk3 -init;
use Glib qw(TRUE FALSE);
use POSIX qw(strftime);

$SIG{CHLD} = 'IGNORE';    # auto-reap tcpdump/pkexec

my $MAX_ROWS    = 2000;
my $SCAN_PORTS  = 10;     # distinct ports from one IP -> flag as scan
my $NOTIFY_GAP  = 60;     # seconds between notifications per source IP
my $FILTER      = 'tcp[tcpflags] & (tcp-syn|tcp-ack) = tcp-syn';

my $ERRFILE = "/tmp/incoming_monitor.$<.err";
my ($fh, $pid, $watch_id, $buf) = (undef, undef, undef, '');
my (%ports_seen, %last_notify);

# ---------- UI ----------
my $win = Gtk3::Window->new('toplevel');
$win->set_title('Incoming Connection Monitor');
$win->set_default_size(760, 460);
$win->signal_connect(destroy => sub { stop_capture(); Gtk3->main_quit });

my $vbox = Gtk3::Box->new('vertical', 6);
$vbox->set_border_width(8);
$win->add($vbox);

my $bar = Gtk3::Box->new('horizontal', 8);
$vbox->pack_start($bar, FALSE, FALSE, 0);

my $btn_toggle = Gtk3::Button->new_with_label('Start');
my $btn_clear  = Gtk3::Button->new_with_label('Clear');
my $chk_lan    = Gtk3::CheckButton->new_with_label('Ignore LAN');
my $chk_notify = Gtk3::CheckButton->new_with_label('Desktop notifications');
$chk_notify->set_active(TRUE);
$bar->pack_start($_, FALSE, FALSE, 0) for ($btn_toggle, $btn_clear, $chk_lan, $chk_notify);

# columns: time, source, source port, dest port, flag, row colour
my $store = Gtk3::ListStore->new(('Glib::String') x 6);
my $tree  = Gtk3::TreeView->new_with_model($store);
my $i = 0;
for my $title ('Time', 'Source IP', 'Src port', 'Local port', 'Flag') {
    my $r   = Gtk3::CellRendererText->new;
    my $col = Gtk3::TreeViewColumn->new_with_attributes($title, $r,
                  text => $i, 'background' => 5);
    $col->set_resizable(TRUE);
    $col->set_sort_column_id($i);
    $tree->append_column($col);
    $i++;
}
my $scroll = Gtk3::ScrolledWindow->new;
$scroll->set_policy('automatic', 'automatic');
$scroll->add($tree);
$vbox->pack_start($scroll, TRUE, TRUE, 0);

my $status = Gtk3::Label->new('Stopped');
$status->set_xalign(0);
$vbox->pack_start($status, FALSE, FALSE, 0);

$btn_toggle->signal_connect(clicked => sub { $pid ? stop_capture() : start_capture() });
$btn_clear->signal_connect(clicked => sub { $store->clear; %ports_seen = () });

# ---------- capture ----------
sub start_capture {
    my $elevate = -x '/usr/bin/pkexec' ? 'pkexec' : 'sudo';
    my @cmd = ($elevate, 'tcpdump', '-l', '-n', '-q', '-i', 'any', $FILTER);

    pipe(my $rd, my $wr) or return set_status("pipe failed: $!");
    $pid = fork();
    return set_status("fork failed: $!") unless defined $pid;

    if ($pid == 0) {                       # child
        close $rd;
        open STDOUT, '>&', $wr or die;
        open STDERR, '>', $ERRFILE;
        exec @cmd or do { print STDERR "could not run $cmd[0]: $!\n"; exit 1 };
    }
    close $wr;
    $fh  = $rd;
    $buf = '';
    $watch_id = Glib::IO->add_watch(fileno($fh), ['in', 'hup'], \&on_data, undef);
    $btn_toggle->set_label('Stop');
    set_status("Capturing via $elevate tcpdump...");
}

sub stop_capture {
    return unless $pid;
    Glib::Source->remove($watch_id) if $watch_id;
    close $fh if $fh;
    # pkexec runs tcpdump as root, so we can't signal it; it exits on its
    # own (SIGPIPE) the next time it tries to write to the closed pipe.
    kill 'TERM', $pid;
    ($fh, $pid, $watch_id) = (undef, undef, undef);
    $btn_toggle->set_label('Start');
    set_status('Stopped');
}

sub on_data {
    my $n = sysread($fh, my $chunk, 8192);
    if (!$n) {                             # EOF or error
        $watch_id = undef;
        close $fh if $fh;
        ($fh, $pid) = (undef, undef);
        $btn_toggle->set_label('Start');
        my $err = '';
        if (open my $ef, '<', $ERRFILE) {
            local $/;
            $err = <$ef> // '';
            close $ef;
            $err =~ s/\s+/ /g;
        }
        set_status('tcpdump exited: ' . ($err ne '' ? substr($err, 0, 200) : 'no error output (auth cancelled or no polkit agent?)'));
        return FALSE;
    }
    $buf .= $chunk;
    while ($buf =~ s/^([^\n]*)\n//) { handle_line($1) }
    return TRUE;
}

sub is_lan {
    return $_[0] =~ /^(?:10\.|192\.168\.|172\.(?:1[6-9]|2\d|3[01])\.|127\.|169\.254\.|fe80|::1$)/i;
}

sub handle_line {
    my $line = shift;
    return unless $line =~ /IP6? ([0-9a-fA-F:.]+)\.(\d+) > [0-9a-fA-F:.]+\.(\d+):/;
    my ($src, $sport, $dport) = ($1, $2, $3);
    return if $chk_lan->get_active && is_lan($src);

    $ports_seen{$src}{$dport} = 1;
    my $scan  = keys %{ $ports_seen{$src} } >= $SCAN_PORTS;
    my $flag  = $scan ? 'PORT SCAN?' : '';
    my $color = $scan ? '#ffb3b3' : (is_lan($src) ? '#ffffff' : '#fff3c4');
    my $now   = strftime('%H:%M:%S', localtime);

    my $iter = $store->append;
    $store->set($iter, 0 => $now, 1 => $src, 2 => $sport, 3 => $dport,
                       4 => $flag, 5 => $color);

    if ($store->iter_n_children(undef) > $MAX_ROWS) {
        $store->remove($store->get_iter_first);
    }
    $tree->scroll_to_cell($store->get_path($iter), undef, FALSE, 0, 0);

    if ($chk_notify->get_active && !is_lan($src)
        && (!$last_notify{$src} || time - $last_notify{$src} > $NOTIFY_GAP)) {
        $last_notify{$src} = time;
        my $msg = $scan ? "Possible port scan from $src" : "$src -> port $dport";
        system("notify-send 'Incoming connection' '$msg' &");   # src is [0-9a-f:.] only
    }
    set_status("Capturing... rows: " . $store->iter_n_children(undef));
}

sub set_status { $status->set_text($_[0]) }

$win->show_all;
Gtk3->main;
