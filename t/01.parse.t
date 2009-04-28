use lib 't';

use Data;

use HTML::Parser::Simple;
use strict;

use Test::More 'no_plan';

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
    my($p) = HTML::Parser::Simple -> new;
    $p -> parse($html);
    $p -> traverse($p -> get_root );
    is($p -> result, $html, 'Input matches output, all upper-case version. ');
}
