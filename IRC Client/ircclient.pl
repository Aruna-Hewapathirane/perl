#!/usr/bin/perl
use strict;
use warnings;
use Gtk3 -init;
use Glib;
use AnyEvent;
use AnyEvent::IRC::Client;

# --- CONFIGURATION ---
my $NICK     = "PerlGtkUser";
my $SERVER   = "irc.libera.chat";
my $PORT     = 6667;
# Add as many channels as you want to this array:
my @CHANNELS = ("#debian", "#perl", "#arduino","#pascal");

# --- APPLICATION STATE ---
my $irc = AnyEvent::IRC::Client->new;
my %channel_tabs; # Tracks GUI elements per channel: { lc($chan) => { text_view => ..., user_list => ... } }

# --- GUI SETUP ---
my $window = Gtk3::Window->new('toplevel');
$window->set_title("Perl Gtk3 Multi-Channel IRC Client");
$window->set_default_size(800, 500);
$window->signal_connect(destroy => sub { Gtk3::main_quit; exit; });

# Main structural container layout
my $main_box = Gtk3::Box->new('vertical', 5);
$window->add($main_box);

# The Notebook widget creates our channel tabs
my $notebook = Gtk3::Notebook->new;
$main_box->pack_start($notebook, 1, 1, 0);

# Single shared text entry box at the bottom
my $entry_box = Gtk3::Entry->new;
$main_box->pack_start($entry_box, 0, 0, 5);

# Dynamically construct UI panels for every channel in our configuration
for my $chan (@CHANNELS) {
    create_channel_tab($chan);
}

# --- HELPER FUNCTIONS ---

# Dynamically builds the UI split-pane inside a new tab sheet
sub create_channel_tab {
    my ($chan_name) = @_;
    my $key = lc($chan_name);
    
    my $paned_layout = Gtk3::Paned->new('horizontal');
    $paned_layout->set_position(600);
    
    # Left: Message view area
    my $left_box = Gtk3::Box->new('vertical', 0);
    my $scroll_window = Gtk3::ScrolledWindow->new;
    my $text_view = Gtk3::TextView->new;
    $text_view->set_editable(0);
    $scroll_window->add($text_view);
    $left_box->pack_start($scroll_window, 1, 1, 0);
    $paned_layout->pack1($left_box, 1, 0);
    
    # Right: Sidebar panel for names
    my $sidebar_scroll = Gtk3::ScrolledWindow->new;
    my $user_list_text = Gtk3::TextView->new;
    $user_list_text->set_editable(0);
    $sidebar_scroll->add($user_list_text);
    $paned_layout->pack2($sidebar_scroll, 0, 1);
    
    # Store references to these fields so event hooks can write to them asynchronously
    $channel_tabs{$key} = {
        text_view => $text_view,
        user_list => $user_list_text,
        name      => $chan_name
    };
    
    # Append the completed paned layout as a page into the notebook layout
    my $tab_label = Gtk3::Label->new($chan_name);
    $notebook->append_page($paned_layout, $tab_label);
}

# Retrieves the channel string linked to the currently active UI tab sheet
sub get_current_active_channel {
    my $current_page_num = $notebook->get_current_page;
    return "" if $current_page_num < 0;
    
    my $nth_page_widget = $notebook->get_nth_page($current_page_num);
    
    # Locate which key in our mapping hash matches this specific widget reference
    for my $key (keys %channel_tabs) {
        if ($channel_tabs{$key}->{widget_ref} //= $nth_page_widget) {
            return $channel_tabs{$key}->{name} if $channel_tabs{$key}->{widget_ref} eq $nth_page_widget;
        }
    }
    return "";
}

# Appends lines to a targeted channel tab layout safely
sub append_chat {
    my ($target_chan, $text) = @_;
    my $key = lc($target_chan);
    return unless exists $channel_tabs{$key};
    
    my $text_view = $channel_tabs{$key}->{text_view};
    my $buffer = $text_view->get_buffer;
    my $end_iter = $buffer->get_end_iter;
    $buffer->insert($end_iter, "$text\n");
    
    my $mark = $buffer->create_mark(undef, $buffer->get_end_iter, 0);
    $text_view->scroll_to_mark($mark, 0.0, 1, 0.0, 1.0);
}

# Updates the targeted tab panel sidebar using memory lists cached by the server state
sub refresh_user_list {
    my ($target_chan) = @_;
    my $key = lc($target_chan);
    return unless exists $channel_tabs{$key};
    
    my $channel_hash = $irc->channel_list($channel_tabs{$key}->{name});
    my @users = $channel_hash ? sort keys %$channel_hash : ($NICK);
    
    @users = map { s/^[\@\+]//; $_ } @users;
    my %seen;
    @users = grep { !$seen{$_}++ } @users;

    my $buffer = $channel_tabs{$key}->{user_list}->get_buffer;
    $buffer->set_text(join("\n", @users));
}

# Centralized routine to distribute incoming strings into the appropriate tabs
sub handle_incoming_public_chat {
    my ($irc, $target_channel, $msg_obj) = @_;
    return unless defined $target_channel;
    return unless defined $msg_obj && ref($msg_obj) eq 'HASH';
    
    my $key = lc($target_channel);
    return unless exists $channel_tabs{$key}; # Drop messages if we aren't tracking that channel tab
    
    my $raw_sender = $msg_obj->{prefix} || "Unknown";
    my $clean_nick = $raw_sender;
    $clean_nick =~ s/!.*//;
    
    my $chat_text = "";
    if (exists $msg_obj->{params} && ref($msg_obj->{params}) eq 'ARRAY') {
        $chat_text = $msg_obj->{params}->[-1];
    }
    
    if (defined $chat_text && $chat_text ne '') {
        append_chat($target_channel, "<$clean_nick> $chat_text");
    }
}

# --- IRC PROTOCOL EVENT HANDLERS ---
$irc->reg_cb(
    connect => sub {
        my ($irc, $err) = @_;
        if (defined $err) {
            for my $k (keys %channel_tabs) { append_chat($channel_tabs{$k}->{name}, "!!! Connection error: $err"); }
            return;
        }
        for my $k (keys %channel_tabs) { append_chat($channel_tabs{$k}->{name}, " Connected! Registering..."); }
    },
    
    registered => sub {
        for my $chan (@CHANNELS) {
            append_chat($chan, " Nickname registered! Joining $chan...");
            $irc->send_srv('JOIN', $chan);
        }
    },
    
    publicmsg    => \&handle_incoming_public_chat,
    chan_privmsg => \&handle_incoming_public_chat,
    
    privmsg => sub {
        my ($irc, $target, $msg_obj) = @_;
        return unless ref($msg_obj) eq 'HASH';
        my $sender = $msg_obj->{prefix} || "Unknown";
        $sender =~ s/!.*//;
        my $text = $msg_obj->{params}->[-1] || "";
        
        # Route DMs into whichever active channel tab is open right now as a fallback notice
        my $active = get_current_active_channel() || $CHANNELS[0];
        append_chat($active, "[DM from $sender] $text");
    },

    join => sub {
        my ($irc, $nick, $chan, $is_me) = @_;
        $nick =~ s/!.*//;
        append_chat($chan, "--> $nick has joined $chan");
        
        if ($is_me) {
            $irc->send_srv('NAMES', $chan);
        }
        refresh_user_list($chan);
    },

    irc_353 => sub {
        my ($irc, $msg) = @_;
        my $chan = $msg->{params}->[2] || ""; # Numeric 353 lists channel target string under index parameter index 2
        return unless $chan;
        Glib::Timeout->add(200, sub {
            refresh_user_list($chan);
            return 0; 
        });
    },

    part => sub {
        my ($irc, $nick, $chan, $msg) = @_;
        $nick =~ s/!.*//;
        append_chat($chan, "<-- $nick has left $chan");
        refresh_user_list($chan);
    },
    
    quit => sub {
        my ($irc, $nick, $msg) = @_;
        $nick =~ s/!.*//;
        # Since a quit drops a user everywhere, update lists across all tabs
        for my $chan (@CHANNELS) {
            append_chat($chan, "<-- $nick has disconnected");
            refresh_user_list($chan);
        }
    }
);

# --- SEND MESSAGE EVENT ---
$entry_box->signal_connect(activate => sub {
    my $text = $entry_box->get_text;
    return if $text eq '';
    
    my $active_channel = get_current_active_channel();
    if ($active_channel eq '') {
        $entry_box->set_text('');
        return;
    }
    
    $irc->send_chan($active_channel, 'PRIVMSG', $active_channel, $text);
    append_chat($active_channel, "<$NICK> $text");
    $entry_box->set_text('');
});

# --- TIMEOUT ASYNC LOOP ---
Glib::Timeout->add(10, sub {
    AE::cv->one_event;
    return 1;
});

# --- EXECUTE ---
for my $chan (@CHANNELS) { append_chat($chan, "Connecting to $SERVER:$PORT..."); }
$irc->connect($SERVER, $PORT, { nick => $NICK });

$window->show_all;
Gtk3::main;
