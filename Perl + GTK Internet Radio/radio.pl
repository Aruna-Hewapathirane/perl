#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use Gtk3 '-init';
use Glib;

# --- Radio Station Database ---
# You can add or replace these URLs with any public streaming links (Icecast, SHOUTcast, etc.)
my @stations = (
    { name => "Kiss 92.5 FM Toronto",   url => "https://rogers-hls.leanstream.co/rogers/tor925.stream/playlist.m3u8"},
    { name => "Reggae FM ",       url => "http://www.partyviberadio.com:8000/listen.pls?sid=1"},
    { name => "Dance Hall UK",    url => "http://uk2.internet-radio.com:8024/"},
    { name => "HIRU FM",          url => "https://radio.lotustechnologieslk.net:2020/stream/hirufmgarden"},
    { name => "Polskie Radio 24", url => "https://stream15.polskieradio.pl/pr24/pr24.sdp/playlist.m3u8"},
    { name => "Technolovers Germany", url => "https://0nlineradio.stream42.radiohost.de/technolovers-melodic-house-techno?upd-meta&upd-scheme=https&_art=dD0xNzg5MTcxNTM4JmQ9ZWUyMzJjMWJkOTZmZmUxOTFiNGQ"},
    { name => "BBC World News", url => "https://as-hls-ww-live.akamaized.net/pool_53367543/live/ww/bbc_sounds_news/bbc_sounds_news.isml/bbc_sounds_news-audio%3d128000.norewind.m3u8"},
);

# Global tracking variable for the background media player process PID
my $player_pid = undef;

# --- Main Window Setup ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Perl GTK Internet Radio');
$window->set_default_size(400, 250);
$window->set_border_width(15);

# Make sure background players are closed cleanly when exiting the window
$window->signal_connect(destroy => \&stop_playback_and_quit);

my $vbox = Gtk3::Box->new('vertical', 12);
$window->add($vbox);

# 1. Header Display
my $status_label = Gtk3::Label->new();
$status_label->set_markup("<span weight='bold' size='large'>Stopped</span>");
$vbox->pack_start($status_label, 0, 0, 5);

# 2. Station Dropdown Selector (ComboBox Text)
my $combo = Gtk3::ComboBoxText->new();
foreach my $station (@stations) {
    $combo->append_text($station->{name});
}
$combo->set_active(0); # Default to the first station
$vbox->pack_start($combo, 0, 0, 5);

# 3. Control Buttons Layout
my $hbox = Gtk3::Box->new('horizontal', 10);
$hbox->set_homogeneous(1); # Make buttons equal width
$vbox->pack_start($hbox, 0, 0, 5);

my $btn_play = Gtk3::Button->new_with_label("▶ Play");
$btn_play->signal_connect(clicked => \&start_playback);
$hbox->pack_start($btn_play, 1, 1, 0);

my $btn_stop = Gtk3::Button->new_with_label("■ Stop");
$btn_stop->signal_connect(clicked => \&stop_playback);
$hbox->pack_start($btn_stop, 1, 1, 0);

# --- Playback Logic ---

sub start_playback {
    # Stop anything currently playing first
    stop_playback();

    my $index = $combo->get_active();
    return if $index < 0;

    my $station_name = $stations[$index]->{name};
    my $station_url  = $stations[$index]->{url};

    $status_label->set_markup("<span foreground='darkgreen' weight='bold' size='large'>Connecting...</span>");

    # Fork a background process to run mpv so the GTK interface stays responsive
    my $pid = fork();

    if (!defined $pid) {
        $status_label->set_markup("<span foreground='red'>Error: Failed to spawn player</span>");
        return;
    }

    if ($pid == 0) {
        # Child process: Open the audio stream in headless/quiet mode
        # Re-route text output to avoid flooding your terminal window
        open(STDOUT, '>', '/dev/null');
        open(STDERR, '>', '/dev/null');
        exec("mpv", "--no-video", $station_url);
        exit(0); 
    } else {
        # Parent process: Save the PID so we can terminate it later
        $player_pid = $pid;
        $status_label->set_markup("<span foreground='blue' weight='bold' size='large'>Playing: $station_name</span>");
    }
}

sub stop_playback {
    if (defined $player_pid) {
        # Send a termination signal to the background process
        kill('TERM', $player_pid);
        waitpid($player_pid, 0);
        $player_pid = undef;
    }
    $status_label->set_markup("<span weight='bold' size='large'>Stopped</span>");
}

sub stop_playback_and_quit {
    stop_playback();
    Gtk3->main_quit();
}

# --- Initialization ---
$window->show_all();
Gtk3->main();

