use lib 't';

use Data;

use HTML::Parser::Simple::Tree;

use Test::More tests => 1;

# -----------------------

my($data)   = Data->new;
my($html)   = $data -> read_file('t/data/04.parse.error.html');
my($parser) = HTML::Parser::Simple::Tree -> new();

eval{$parser -> parse($html)};

ok($@ =~ /Parse error/, 'Parse error as expected');

