<img width="671" height="507" alt="image" src="https://github.com/user-attachments/assets/c8e5bdfc-4e65-48c7-8524-c07c2e4fcb1e" />



1. Fill the form then click save.
2. Your data will populate grid view below
3. Double click grid view data row
4. The form entry text inputs will populate so you can now edit/make changes
5. Click save
6. Wash -Rinse -Repeat

[Word of warning, SQLite does not work in UTF8 mode by default AFAIK](https://github.com/bbrtj/perl-brulion-api/blob/master/lib/BrulionAPI/DB.pm#L7)

You may need to install:
1. sudo apt install libdbi-perl
2. sudo apt install libdbd-sqlite3-perl
