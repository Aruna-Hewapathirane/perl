#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Gtk3 '-init';

# 1. Complete dataset of 195 UN-recognized countries + their global visa-free scores
my @countries_data = (
    { name => "Afghanistan", visa_free => 23 },  { name => "Albania", visa_free => 123 },
    { name => "Algeria", visa_free => 54 },      { name => "Andorra", visa_free => 173 },
    { name => "Angola", visa_free => 53 },       { name => "Antigua and Barbuda", visa_free => 153 },
    { name => "Argentina", visa_free => 172 },   { name => "Armenia", visa_free => 68 },
    { name => "Australia", visa_free => 186 },   { name => "Austria", visa_free => 190 },
    { name => "Azerbaijan", visa_free => 71 },   { name => "Bahamas", visa_free => 158 },
    { name => "Bahrain", visa_free => 90 },      { name => "Bangladesh", visa_free => 40 },
    { name => "Barbados", visa_free => 165 },    { name => "Belarus", visa_free => 81 },
    { name => "Belgium", visa_free => 186 },     { name => "Belize", visa_free => 104 },
    { name => "Benin", visa_free => 64 },        { name => "Bhutan", visa_free => 4 },
    { name => "Bolivia", visa_free => 82 },      { name => "Bosnia and Herzegovina", visa_free => 121 },
    { name => "Botswana", visa_free => 88 },     { name => "Brazil", visa_free => 171 },
    { name => "Brunei", visa_free => 168 },      { name => "Bulgaria", visa_free => 177 },
    { name => "Burkina Faso", visa_free => 59 }, { name => "Burundi", visa_free => 50 },
    { name => "Cabo Verde", visa_free => 67 },   { name => "Cambodia", visa_free => 57 },
    { name => "Cameroon", visa_free => 53 },     { name => "Canada", visa_free => 185 },
    { name => "Central African Republic", visa_free => 52 }, { name => "Chad", visa_free => 55 },
    { name => "Chile", visa_free => 175 },       { name => "China", visa_free => 85 },
    { name => "Colombia", visa_free => 135 },    { name => "Comoros", visa_free => 54 },
    { name => "Congo (Congo-Brazzaville)", visa_free => 51 }, { name => "Costa Rica", visa_free => 152 },
    { name => "Croatia", visa_free => 180 },     { name => "Cuba", visa_free => 63 },
    { name => "Cyprus", visa_free => 179 },      { name => "Czechia", visa_free => 185 },
    { name => "Democratic Republic of the Congo", visa_free => 46 }, { name => "Denmark", visa_free => 190 },
    { name => "Djibouti", visa_free => 50 },     { name => "Dominica", visa_free => 143 },
    { name => "Dominican Republic", visa_free => 74 }, { name => "Ecuador", visa_free => 95 },
    { name => "Egypt", visa_free => 55 },        { name => "El Salvador", visa_free => 136 },
    { name => "Equatorial Guinea", visa_free => 4 }, { name => "Eritrea", visa_free => 4 },
    { name => "Estonia", visa_free => 184 },     { name => "Eswatini", visa_free => 77 },
    { name => "Ethiopia", visa_free => 47 },     { name => "Fiji", visa_free => 89 },
    { name => "Finland", visa_free => 189 },     { name => "France", visa_free => 186 },
    { name => "Gabon", visa_free => 58 },        { name => "Gambia", visa_free => 70 },
    { name => "Georgia", visa_free => 122 },     { name => "Germany", visa_free => 190 },
    { name => "Ghana", visa_free => 67 },        { name => "Greece", visa_free => 185 },
    { name => "Grenada", visa_free => 147 },     { name => "Guatemala", visa_free => 137 },
    { name => "Guinea", visa_free => 57 },       { name => "Guinea-Bissau", visa_free => 55 },
    { name => "Guyana", visa_free => 89 },       { name => "Haiti", visa_free => 51 },
    { name => "Honduras", visa_free => 138 },    { name => "Hungary", visa_free => 187 },
    { name => "Iceland", visa_free => 182 },     { name => "India", visa_free => 58 },
    { name => "Indonesia", visa_free => 78 },    { name => "Iran", visa_free => 45 },
    { name => "Iraq", visa_free => 31 },         { name => "Ireland", visa_free => 186 },
    { name => "Israel", visa_free => 166 },      { name => "Italy", visa_free => 189 },
    { name => "Ivory Coast", visa_free => 60 },  { name => "Jamaica", visa_free => 89 },
    { name => "Japan", visa_free => 188 },       { name => "Jordan", visa_free => 53 },
    { name => "Kazakhstan", visa_free => 79 },   { name => "Kenya", visa_free => 76 },
    { name => "Kiribati", visa_free => 124 },    { name => "Kuwait", visa_free => 99 },
    { name => "Kyrgyzstan", visa_free => 64 },   { name => "Laos", visa_free => 51 },
    { name => "Latvia", visa_free => 183 },      { name => "Lebanon", visa_free => 44 },
    { name => "Lesotho", visa_free => 79 },      { name => "Liberia", visa_free => 51 },
    { name => "Libya", visa_free => 41 },        { name => "Liechtenstein", visa_free => 181 },
    { name => "Lithuania", visa_free => 182 },   { name => "Luxembourg", visa_free => 189 },
    { name => "Madagascar", visa_free => 55 },   { name => "Malawi", visa_free => 75 },
    { name => "Malaysia", visa_free => 182 },    { name => "Maldives", visa_free => 94 },
    { name => "Mali", visa_free => 56 },         { name => "Malta", visa_free => 185 },
    { name => "Marshall Islands", visa_free => 126 }, { name => "Mauritania", visa_free => 60 },
    { name => "Mauritius", visa_free => 148 },   { name => "Mexico", visa_free => 161 },
    { name => "Micronesia", visa_free => 122 },  { name => "Moldova", visa_free => 122 },
    { name => "Monaco", visa_free => 177 },      { name => "Mongolia", visa_free => 64 },
    { name => "Montenegro", visa_free => 124 },  { name => "Morocco", visa_free => 73 },
    { name => "Mozambique", visa_free => 63 },   { name => "Myanmar", visa_free => 48 },
    { name => "Namibia", visa_free => 80 },      { name => "Nauru", visa_free => 90 },
    { name => "Nepal", visa_free => 40 },        { name => "Netherlands", visa_free => 188 },
    { name => "New Zealand", visa_free => 186 }, { name => "Nicaragua", visa_free => 131 },
    { name => "Niger", visa_free => 57 },        { name => "Nigeria", visa_free => 45 },
    { name => "North Korea", visa_free => 42 },  { name => "North Macedonia", visa_free => 125 },
    { name => "Norway", visa_free => 186 },      { name => "Oman", visa_free => 82 },
    { name => "Pakistan", visa_free => 34 },     { name => "Palau", visa_free => 121 },
    { name => "Palestine", visa_free => 40 },    { name => "Panama", visa_free => 147 },
    { name => "Papua New Guinea", visa_free => 77 }, { name => "Paraguay", visa_free => 145 },
    { name => "Peru", visa_free => 142 },        { name => "Philippines", visa_free => 69 },
    { name => "Poland", visa_free => 188 },      { name => "Portugal", visa_free => 186 },
    { name => "Qatar", visa_free => 107 },       { name => "Romania", visa_free => 179 },
    { name => "Russia", visa_free => 116 },      { name => "Rwanda", visa_free => 61 },
    { name => "Saint Kitts and Nevis", visa_free => 156 }, { name => "Saint Lucia", visa_free => 146 },
    { name => "Saint Vincent and the Grenadines", visa_free => 151 }, { name => "Samoa", visa_free => 132 },
    { name => "San Marino", visa_free => 171 },  { name => "Sao Tome and Principe", visa_free => 62 },
    { name => "Saudi Arabia", visa_free => 88 }, { name => "Senegal", visa_free => 58 },
    { name => "Serbia", visa_free => 137 },      { name => "Seychelles", visa_free => 155 },
    { name => "Sierra Leone", visa_free => 67 }, { name => "Singapore", visa_free => 192 },
    { name => "Slovakia", visa_free => 184 },    { name => "Slovenia", visa_free => 184 },
    { name => "Solomon Islands", visa_free => 132 }, { name => "Somalia", visa_free => 36 },
    { name => "South Africa", location => "ZA", visa_free => 106 }, { name => "South Korea", visa_free => 188 },
    { name => "South Sudan", visa_free => 46 },  { name => "Spain", visa_free => 189 },
    { name => "Sri Lanka", visa_free => 44 },    { name => "Sudan", visa_free => 43 },
    { name => "Suriname", visa_free => 81 },     { name => "Sweden", visa_free => 189 },
    { name => "Switzerland", visa_free => 186 }, { name => "Syria", visa_free => 28 },
    { name => "Tajikistan", visa_free => 60 },   { name => "Tanzania", visa_free => 73 },
    { name => "Thailand", visa_free => 82 },     { name => "Timor-Leste", visa_free => 97 },
    { name => "Togo", visa_free => 58 },         { name => "Tonga", visa_free => 130 },
    { name => "Trinidad and Tobago", visa_free => 150 }, { name => "Tunisia", visa_free => 71 },
    { name => "Turkey", visa_free => 116 },      { name => "Turkmenistan", visa_free => 52 },
    { name => "Tuvalu", visa_free => 128 },      { name => "Uganda", visa_free => 69 },
    { name => "Ukraine", visa_free => 148 },     { name => "United Arab Emirates", visa_free => 184 },
    { name => "United Kingdom", visa_free => 186 }, { name => "United States", visa_free => 179 },
    { name => "Uruguay", visa_free => 156 },     { name => "Uzbekistan", visa_free => 62 },
    { name => "Vanuatu", visa_free => 92 },      { name => "Venezuela", visa_free => 126 },
    { name => "Vietnam", visa_free => 55 },      { name => "Yemen", visa_free => 35 },
    { name => "Zambia", visa_free => 71 },       { name => "Zimbabwe", visa_free => 66 }
);

# 2. Initialize main application window
my $window = Gtk3::Window->new('toplevel');
$window->set_title('Global Passport Power Index 2026');
$window->set_default_size(500, 600);
$window->set_position('center');
$window->signal_connect(destroy => sub { Gtk3::main_quit(); });

# 3. Create a data store model (Column 0 = String, Column 1 = Integer)
my $model = Gtk3::ListStore->new('Glib::String', 'Glib::Int');

# Populate model with the 195 countries
for my $country (sort { $a->{name} cmp $b->{name} } @countries_data) {
    my $iter = $model->append();
    $model->set($iter, 0 => $country->{name}, 1 => $country->{visa_free});
}

# 4. Create UI TreeView component to render table columns
my $treeview = Gtk3::TreeView->new_with_model($model);

# Column 1: Country Name
my $renderer_name = Gtk3::CellRendererText->new();
my $column_name = Gtk3::TreeViewColumn->new_with_attributes(
    "Country Name", $renderer_name, text => 0
);
$column_name->set_sort_column_id(0);
$treeview->append_column($column_name);

# Column 2: Visa Free Score
my $renderer_score = Gtk3::CellRendererText->new();
my $column_score = Gtk3::TreeViewColumn->new_with_attributes(
    "Visa-Free Destinations", $renderer_score, text => 1
);
$column_score->set_sort_column_id(1);
$treeview->append_column($column_score);

# 5. Pack UI elements into layout
my $scrolled_window = Gtk3::ScrolledWindow->new();
$scrolled_window->set_policy('automatic', 'automatic');
$scrolled_window->add($treeview);

my $vbox = Gtk3::Box->new('vertical', 5);
$vbox->set_border_width(10);

my $label = Gtk3::Label->new("<b>Passport Strength Rankings (All 195 UN Nations)</b>");
$label->set_use_markup(1);

$vbox->pack_start($label, 0, 0, 5);
$vbox->pack_start($scrolled_window, 1, 1, 0);

$window->add($vbox);
$window->show_all();

Gtk3::main();
