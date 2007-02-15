#!perl -T

use Test::More;
eval "use Test::Pod::Coverage 1.08";
plan skip_all => "Test::Pod::Coverage 1.08 required for testing POD coverage"
  if $@;

# XXX: Decide which of these must really be doc'd and which should be _'d.
my $trustme = [ qw(
  deliver
  fix_lines
  get_filename_in
  update_time
  write_links
  write_message
  write_temp
  getlock                                      
  unlock
) ];

all_pod_coverage_ok({
  trustme => $trustme,
  coverage_class => 'Pod::Coverage::CountParents'
});
