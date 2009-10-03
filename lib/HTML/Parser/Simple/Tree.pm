package HTML::Parser::Simple::Tree;
use base 'HTML::Parser::Simple';
use strict;
use warnings;

use Tree::Simple;

=head1 Synopsis

	use HTML::Parser::Simple::Tree;
	my $p = HTML::Parser::Simple:Tree->new;
	
	$p->parse_file('in.html', 'out.html');
    # or 
	$p->parse('<html>...</html>');
	
	$p->traverse($p -> get_root() );
	print $p->result();

=cut 

sub init {
    my $self = shift;
    my @args = @_;

    $self->SUPER::init(@_); 

    # XXX This default may change. 
    $self->case_sensitive(1);

    # The result of of traverse();
	$$self{'_result'}    = '';

	# Note: set_depth() and set_node_type() must be called before create_new_node().
	$self -> set_depth(0);
	$self -> set_node_type('global');
	$self -> set_current_node($self -> create_new_node('root', '') );
	$self -> set_root($self -> get_current_node() );
    return $self;
}


# -----------------------------------------------
# Create a new node to store the new tag.
# Each node has metadata:
# o orig_text   The tag before it was parsed.
# o content:    The content before the tag was parsed.
# o name:       The HTML tag.
# o node_type:  This holds 'global' before '<head>' and between '</head>'
#               and '<body>', and after '</body>'. It holds 'head' from
#               '<head>' to </head>', and holds 'body' from '<body>' to
#               '</body>'. It's just there in case you need it.
sub create_new_node
{
	my($self, $name, $orig_text, $parent) = @_;
	my($metadata) =
	{
        orig_text  => $orig_text,
		content    => [],
		depth      => $self -> get_depth(),
		name       => $name,
		node_type  => $self -> get_node_type(),
	};

	return Tree::Simple -> new($metadata, $parent);

} # End of create_new_node.

# -----------------------------------------------

sub get_current_node
{
	my($self) = @_;

	return $$self{'_current'};

} # End of get_current_node.

sub handle_end_tag
{
	my($self, $tag_name) = @_;

    my $lc_tag_name = lc $tag_name;

	if ( ($lc_tag_name eq 'head') || ($lc_tag_name eq 'body') )
	{
		$self -> set_node_type('global');
	}

	if (! $$self{'_empty'}{$lc_tag_name})
	{
         my $parent = $self -> get_current_node() -> getParent();
        # root is not an object so need special handling. 
        if ($parent eq 'root') {
            $self -> set_current_node($self->get_root ); 
            $self -> set_depth(0);
        }
        else {
            $self -> set_current_node($parent);
            $self -> set_depth($self -> get_depth - 1);
        }
	}

} # End of handle_end_tag.

sub comment {
    my ($self,$comment) = @_;
    return $self->handle_content($comment);
}

sub declaration {
    my ($self,$xml,$declaration) = @_;
    return $self->handle_content($declaration);
}

sub handle_content
{
	my($self, $s)                 = @_;
	my($count)                    = $self -> get_current_node() -> getChildCount();
	my($metadata)                 = $self -> get_current_node() -> getNodeValue();
	$$metadata{'content'}[$count] .= $s;

	$self -> get_current_node() -> setNodeValue($metadata);

} # End of handle_content.



sub start {
	my($self, $tag_name, $attr_href, $attr_seq, $orig_text) = @_;

	$self -> set_depth($self -> get_depth() + 1);

	if ($tag_name eq 'head')
	{
		$self -> set_node_type('head');
	}
	elsif ($tag_name eq 'body')
	{
		$self -> set_node_type('body');
	}

	my($node) = $self -> create_new_node($tag_name, $orig_text, $self -> get_current_node() );

	if (! $$self{'_empty'}{$tag_name})
	{
		$self -> set_current_node($node);
	}

}

sub parse_file
{
	my($self, $input_file_name, $output_file_name) = @_;

	open(INX, $input_file_name) || Carp::croak "Can't open($input_file_name): $!";
	my($html);
	read(INX, $html, -s INX);
	close INX;

	if (! defined $html)
	{
		Carp::croak "Can't read($input_file_name): $!"
	}

	$self -> parse($html);
	$self -> traverse($self -> get_root() );

	open(OUT, "> $output_file_name") || Carp::croak "Can't open(> $output_file_name): $!";
	print OUT $$self{'_result'};
	close OUT;

}

sub get_depth {
	my($self) = @_;
	return $$self{'_depth'};
} 

sub get_root {
	my($self) = @_;
	return $$self{'_root'};
} 

sub set_root
{
	my($self, $node) = @_;

	if (! defined $node)
	{
		Carp::croak "set_root() called with undef";
	}

	$$self{'_root'} = $node;

	return;

} # End of set_root.



sub traverse
{
	my($self, $node) = @_;
	my(@child)       = $node -> getAllChildren();
	my($metadata)    = $node -> getNodeValue();
	my($content)     = $$metadata{'content'};
	my($name)        = $$metadata{'name'};

	# Special check to avoid printing '<root>' when we still need to output
	# the content of the root, e.g. the DOCTYPE.

	if ($name ne 'root')
	{
		$$self{'_result'} .= $$metadata{'orig_text'};
	}

	my($index);
	my($s);

	for $index (0 .. $#child)
	{
		$$self{'_result'} .= $index <= $#$content && defined($$content[$index]) ? $$content[$index] : '';
		$self -> traverse($child[$index]);
	}

	# Output the content after the last child node has been closed,
	# but before the current node is closed.

	$index = $#child + 1;

    my $maybe_content = $index <= $#$content && defined($$content[$index]) ? $$content[$index] : '';
	$$self{'_result'} .= $maybe_content;

    my $lc_name = lc $name;
	if ((not $$self{'_empty'}{$lc_name}) && ($name ne 'root') )
	{
         $$self{'_result'} .= "</$name>";
	}

} # End of traverse.

sub set_depth {
	my($self, $depth) = @_;

	if (! defined $depth) {
		Carp::croak "set_depth() called with undef";
	}

	$$self{'_depth'} = $depth;
	return;
}


sub handle_parse_error {
    my ($self,$remaining_html) = @_;

    my($msg)    = 'Parse error. ';

    my($parent) = $self -> get_current_node() -> getParent();
    my($metadata);

    if ($parent && $parent -> can('getNodeValue') ) {
        $metadata = $parent -> getNodeValue();
        $msg      .= "Parent tag: <$$metadata{'name'}>. ";
    }

    $metadata = $self -> get_current_node() -> getNodeValue();
    $msg      .= "Current tag: <$$metadata{'name'}>. ";

    $msg .= 'Next 100 chars: '. substr($remaining_html, 0, 100);
    Carp::croak $msg;
}

sub get_node_type {
	my($self) = @_;
	return $$self{'_node_type'};
}

sub set_current_node {
	my($self, $node) = @_;

	if (! defined $node) {
		Carp::croak "set_current_node() called with undef";
	}
    elsif (! ref $node ) {
        Carp::confess "set_current_node() called with non reference: $node"; 
    }

	$$self{'_current'} = $node;

	return;

}

sub set_node_type {
	my($self, $type) = @_;

	if (! defined $type) {
		Carp::croak "set_node_type() called with undef";
	}

	$$self{'_node_type'} = $type;
	return;
}

# Perhaps should "get_traverse_result" to be consistent and clear
sub result {
	my($self) = @_;
	return $$self{'_result'};
}





=head1 Method: get_root()

Returns the node which the parser calls the root of the tree of nodes.

=head1 Method: set_root($node)

Returns the node which the parser calls the root of the tree of nodes.

Returns undef.

=head1 Method: parse($html)

Parses the string of HTML in $html, and builds a tree of nodes.

After calling C<< $p -> parse() >>, you must call C<< $p -> traverse($p -> get_root() ) >> before calling C<< $p -> result() >>.

Alternately, call C<< $p -> parse_file() >>, which calls all these methods for you.

Note: C<parse()> may be called directly or via C<parse_file()>.

=head1 Method: parse_file($input_file_name, $output_file_name)

Parses the HTML in the input file, and writes the result to the output file.

=head1 Method: result()

Returns the result so far of the parse.

=head1 Method: set_current_node($node)

Sets the node which the parser calls the current node.

Returns undef.

=head1 Method: get_depth()

Returns the nesting depth of the current tag.

=head1 Method: set_depth($depth)

Sets the nesting depth of the current node. The root is at depth 0

Returns undef.

=head1 Method: result()

Returns the result so far of the parse.

=head1 Method: get_current_node()

Returns the L<Tree::Simple> object which the parser calls the current node.

=head1 Method: get_node_type()

Returns the type of the most recently created node, 'global', 'head', or 'body'.

See the first question in the FAQ for details.

=head1 Method: set_node_type($node_type)

Sets the type of the next node to be created, 'global', 'head', or 'body'.

See the first question in the FAQ for details.

Returns undef.




=head1 FAQ

=over 4

=item What is the format of the data stored in each node of the tree?

The data of each node is a hash ref. The keys/values of this hash ref are:

=over 4

=item orig_text

The full HTML tag.

=item content

This is an array ref of bits and pieces of content.

Consider this fragment of HTML:

<p>I did <i>not</i> say I <i>liked</i> debugging.</p>

When parsing 'I did ', the number of child nodes (of <p>) is 0, since <i> has not yet been detected.

So, 'I did ' is stored in the 0th element of the array ref.

Likewise, 'not' is stored in the 0th element of the array ref belonging to the node 'i'.

Next, ' say I ' is stored in the 1st element of the array ref, because it follows the 1st child node (<i>).

Likewise, ' debugging' is stored in the 2nd element.

This way, the input string can be reproduced by successively outputting the elements of the array ref of content
interspersed with the contents of the child nodes (processed recusively).

Note: If you are processing this tree, never forget that there can be content after the last child node has been closed,
but before the current node is closed.

Note: The DOCTYPE declaration is stored as the 0th element of the content of the root node.

=item depth

The nesting depth of the tag within the document.

The root is at depth 0, '<html>' is at depth 1, '<head>' and '<body>' are a depth 2, and so on.

It's just there in case you need it.

=item The name the HTML tag

So, the tag '<html>' will mean the name is 'html'.

The root of the tree is called 'root', and holds the DOCTYPE, if any, as content.

The root has the node 'html' as the only child, of course.

=item node_type

This holds 'global' before '<head>' and between '</head>' and '<body>', and after '</body>'.

It holds 'head' for all nodes from '<head>' to '</head>', and holds 'body' from '<body>' to '</body>'.

It's just there in case you need it.

=back

=item How are HTML comments handled?

They are treated as content. This includes the prefix '<!--' and the suffix '-->'.

=item How is DOCTYPE handled?

It is treated as content belonging to the root of the tree.

=item How is the XML declaration handled?

It is treated as content belonging to the root of the tree.

=item Does this module handle all HTML pages?

No, never.

=item Which versions of HTML does this module handle?

Up to V 4.

=item What do I do if this module does not handle my HTML page?

Make yourself a nice cup of tea, and then fix your page.

=item Does this validate the HTML input?

No.

For example, if you feed in a HTML page without the title tag, this module does not care.

=item How do I view the output HTML?

By installing HTML::Revelation, of course!

Sample output:

http://savage.net.au/Perl-modules/html/CreateTable.html

=item How do I test this module (or my file)?

Suggested steps:

Note: There are quite a few files involved. Proceed with caution.

=over 4

=item Select a HTML file to test

Call this input.html.

=item Run input.html thru reveal.pl

Reveal.pl ships with HTML::Revelation.

Call the output file output.1.html.

=item Run input.html thru parse.html.pl

Parse.html.pl ships with HTML::Parser::Simple.

Call the output file parsed.html.

=item Run parsed.html thru reveal.pl

Call the output file output.2.html.

=item Compare output.1.html and output.2.html

If they match, or even if they don't match, you're finished.

=back

=item Will you implement a 'quirks' mode to handle my special HTML file?

No, never.

Help with quirks:

http://www.quirksmode.org/sitemap.html

=item Is there anything I should be aware of?

Yes. If your HTML file is not nice, the interpretation of tag nesting will not match
your preconceptions.

In such cases, do not seek to fix the code. Instead, fix your (faulty) preconceptions, and fix your HTML file.

The 'a' tag, for example, is defined to be an inline tag, but the 'div' tag is a block-level tag.

I don't define 'a' to be inline, others do, e.g. http://www.w3.org/TR/html401/ and hence HTML::Tagset.

Inline means:

	<a href = "#NAME"><div class = 'global_toc_text'>NAME</div></a>

will I<not> be parsed as an 'a' containing a 'div'.

The 'a' tag will be closed before the 'div' is opened. So, the result will look like:

	<a href = "#NAME"></a><div class = 'global_toc_text'>NAME</div>

To achieve what was presumably intended, use 'span':

	<a href = "#NAME"><span class = 'global_toc_text'>NAME</span></a>

Some people (*cough* *cough*) have had to redo their entire websites due to this very problem.

Of course, this is just one of a vast set of possible problems.

You have been warned.

=item Why did you use Tree::Simple but not Tree or Tree::Fast or Tree::DAG_Node?

During testing, Tree::Fast crashed, so I replaced it with Tree and everything worked. Spooky.

Late news: Tree does not cope with an array ref stored in the metadata, so I've switched to Tree::DAG_Node.

Stop press: As an experiment I switched to Tree::Simple. Since it also works I'll just keep using it.

=item Why isn't this module called HTML::Parser::PurePerl?

=over 4

=item The API

That name sounds like a pure Perl version of the same API as used by HTML::Parser.

But the API's are not, and are not meant to be, compatible.

=item The tie-in

Some people might falsely assume HTML::Parser can automatically fall back to HTML::Parser::PurePerl in the absence of a compiler.

=back

=item How do I output my own stuff while traversing the tree?

=over 4

=item The sophisticated way

As always with OO code, sub-class! In this case, you write a new version of the traverse() method.

=item The crude way

Alternately, implement another method in your sub-class, e.g. process(), which recurses like traverse().
Then call parse() and process().

=back

=item Is the code on github?

Yes. See: git://github.com/ronsavage/html--parser--simple.git

=item How is the source formatted?

I edit with Emacs, using the default formatting for Perl.

That means, in general, leading 4-space tabs. Hashrefs use a leading tab and then a space.

All vertical alignment within lines is done manually with spaces.

Perl::Critic is off the agenda.

=back

=head1 Required Modules

=over 4

=item Carp

=item Tree::Simple

=cut

1;
