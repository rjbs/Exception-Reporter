use strict;
use warnings;
package Exception::Reporter::Summarizer::Fallback;
use parent 'Exception::Reporter::Summarizer';

use YAML::XS ();
use Try::Tiny;

sub can_summarize { 1 }

sub summarize {
  my ($self, $entry) = @_;
  my ($name, $value, $arg) = @$entry;

  my $fn_base = $self->sanitize_filename($name);

  return try {
    my $body  = ref $value     ? YAML::XS::Dump($value)
              : defined $value ? $value
              :                  "(undef)";;

    my $ident = $body;
    $ident =~ s/\A---\s*// if ref $value; # strip the document marker

    # If we've got a Perl-like exception string, make it more generic by
    # stripping the throw location.
    $ident =~ s/\s+(?:at .+?)? ?line\s\d+\.?$//;

    return {
      filename => "$fn_base.txt",
      mimetype => 'text/plain',
      ident    => $ident,
      body     => $body,
    };
  } catch {
    return(
      {
        filename => "$fn_base-error.txt",
        mimetype => 'text/plain',
        ident    => "value for $name couldn't be processed",
        body     => "could not summarize $name value: $_\n",
      },
      {
        filename => "$fn_base-raw.txt",
        mimetype => 'text/plain',
        ident    => "stringified value for $name",
        body     => do { no warnings 'uninitialized'; "$name" },
      },
    );
  };
}

1;