use strict;
use warnings;
use Test::More;

# generated by Dist::Zilla::Plugin::Test::PodSpelling 2.006001
use Test::Spelling 0.12;
use Pod::Wordlist;


add_stopwords(<DATA>);
all_pod_files_spelling_ok( qw( bin lib  ) );
__DATA__
destructor
fatpacking
interoperability
linearized
David
Golden
dagolden
Dagfinn
Ilmari
Mannsåker
ilmari
Gelu
Lupas
gelu
Karen
Etheridge
ether
Matt
Trout
mstrout
Olivier
Mengué
dolmen
Toby
Inkster
tobyink
lib
Class
Tiny
