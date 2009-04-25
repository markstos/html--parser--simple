use lib 't';

use Data;

use HTML::Parser::Simple;

use Test::More tests => 2;

# -----------------------

my($data)   = Data -> new({input_dir => 't/data'});
my($html)   = $data -> read_file('01.parse.html');
my($parser) = HTML::Parser::Simple -> new();

$parser -> parse($html);
$parser -> traverse($parser -> get_root() );

is($html, $parser -> result(), 'Input matches output');

{
    my($p) = HTML::Parser::Simple -> new;
    my $uc_html = uc $html;
    $p -> parse($uc_html);
    $p -> traverse($p -> get_root );
    is($p -> result, $uc_html, 'Input matches output, all upper-case version. ');
}
