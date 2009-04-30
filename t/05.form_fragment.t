use lib 't';

use Data;

use HTML::Parser::Simple;

use Test::More tests => 1;

# -----------------------

my($data)   = Data->new;
my($html)   = $data -> read_file('t/data/05.form_fragment.html');
my($parser) = HTML::Parser::Simple -> new();

$parser -> parse($html);
$parser -> traverse($parser -> get_root() );

my $result =  $parser -> result;

is($result, $html , 'Input matches output');


