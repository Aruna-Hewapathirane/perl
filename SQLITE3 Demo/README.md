<img width="671" height="507" alt="image" src="https://github.com/user-attachments/assets/cd4affec-6c2f-43c0-b63e-c7ca0d4c4c86" />


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
