use lib 't';

use Data;

use HTML::Parser::Simple::Tree;
use strict;

use Test::More 'no_plan';

# -----------------------

my($data)   = Data -> new;
my($html)   = $data -> read_file('t/data/01.parse.html');
my($parser) = HTML::Parser::Simple::Tree -> new();

$parser -> parse($html);
$parser -> eof;
$parser -> traverse($parser -> get_root() );

is($html, $parser -> result(), 'Input matches output');

{
    my($p) = HTML::Parser::Simple::Tree -> new;
    my $uc_html = uc $html;
    $p -> parse($uc_html);
    $p ->eof;
    $p -> traverse($p -> get_root );
    is($p -> result, $uc_html, 'Input matches output, all upper-case version. ');
}

{
    my $html = '<h1>test<h2>headers</h1>';

    my $p = HTML::Parser::Simple::Tree -> new;
    my $returned = $p -> parse($html);
    $p->eof;

    is( (ref $returned), "HTML::Parser::Simple::Tree", "parse() returns parser object, like HTML::Parser does.");

    $p -> traverse($p -> get_root );
            is($p -> result, '<h1>test<h2>headers</h2></h1>'
                , 'testing <h1> and <h2> tags, which are not mentioned in the source');
}

{
    my $html_1 = '<h1>test<h2>';
    my $html_2 = 'headers</h1>';

    my $p = HTML::Parser::Simple::Tree -> new;
       $p -> parse($html_1);
       $p -> parse($html_2);

    $p -> traverse($p -> get_root );
            is($p -> result, '<h1>test<h2>headers</h2></h1>'
                , 'Basic test of calling parse() repeatedly, like HTML::Parser');
}

TODO: {
my $html =<<"__HTML__";
<HTML>
<BODY>
<FORM action="test.cgi" method="POST">
<INPUT type="hidden" name="hidden" value="&gt;&quot;">
<INPUT type="text" name="text" value="&lt;&gt;&quot;&otilde;"><BR>
<INPUT type="radio" name="radio" value="&quot;&lt;&gt;">test<BR>
<INPUT type="checkbox" name="checkbox" value="&quot;&lt;&gt;">test<BR>
<INPUT type="checkbox" name="checkbox" value="&quot;&gt;&lt;&gt;">test<BR>
<SELECT name="select">
<OPTION value="&lt;&gt;">&lt;&gt;
<OPTION value="&gt;&gt;">&gt;&gt;
<OPTION value="&otilde;">&lt;&lt;
<OPTION>&gt;&gt;&gt;
</SELECT><BR>
<TEXTAREA name="textarea" rows="5">&lt;&gt;&quot;</TEXTAREA><P>
<INPUT type="submit" value=" OK ">
</FORM>
</BODY>
</HTML>
__HTML__

    local $TODO = "need a better HTML comparision tool that allows for differences in line breaks, etc"; 
    my($p) = HTML::Parser::Simple::Tree -> new;
    $p -> parse($html);
    $p -> traverse($p -> get_root );
    is($p -> result, $html, 'Input matches output, all upper-case version. ');
}
