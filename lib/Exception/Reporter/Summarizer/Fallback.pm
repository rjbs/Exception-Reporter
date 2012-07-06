use strict;
use warnings;
package Exception::Reporter::Summarizer::Fallback;
use parent 'Exception::Reporter::Summarizer';

=head1 OVERVIEW

This summarizer will accept any input and summarize it by dumping it to YAML.

I recommended that this summarizer is always in your list of summarizers,
and always last.

If a YAML dump can't be produced, the exception from YAML will be attached,
along with the stringification of the dumpable value.

=cut

use Try::Tiny;

sub can_summarize { 1 }

sub summarize {
  my ($self, $entry, $internal_arg) = @_;
  my ($name, $value, $arg) = @$entry;

  my $fn_base = $self->sanitize_filename($name);

  my $dump = $self->dump($value, { basename => $fn_base });

  return {
    filename => "$fn_base.txt",
    ident    => "dump of $name",
    %$dump,
  };
}

1;
