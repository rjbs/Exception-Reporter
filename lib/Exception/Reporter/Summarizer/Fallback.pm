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

  my $dump = $internal_arg->{dumper}->dump($value);

  # XXX: BIG MESS BEGINS
  my $ident = $dump->{body};
  $ident =~ s/\A---\s*// if ref $value; # strip the document marker

  # If we've got a Perl-like exception string, make it more generic by
  # stripping the throw location.
  $ident =~ s/\s+(?:at .+?)? ?line\s\d+\.?$//;
  # XXX: BIG MESS ENDS

  return {
    filename => "$fn_base.yaml",
    mimetype => $dump->{mimetype},
    ident    => $dump->{ident} || "dump of $name",
    body     => $dump->{body},
  };
}

1;
