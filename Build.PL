use Module::Build;

my($builder) = Module::Build -> new
(
	module_name    => 'HTML::Parser::Simple',
	license        => 'artistic',
	dist_abstract  => 'Parse nice HTML files without needing a compiler',
	dist_author    => 'Ron Savage <ron@savage.net.au>',
	build_requires =>
	{
		Test::More => 0,
		Test::Pod  => 0,
	},
	requires =>
	{
		Carp         => 0,
		Tree::Simple => 0,
        perl         => 5.006,
	},
    meta_merge => {
      resources => {
          repository => 'http://github.com/markstos/html--parser--simple',
      },
  },
);

$builder -> create_build_script();
