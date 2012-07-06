use strict;
use warnings;
package Exception::Reporter::Dumper::YAML;
use parent 'Exception::Reporter::Dumper';

use Try::Tiny;
use YAML ();

sub dump {
  my ($self, $value, $arg) = @_;
  my $basename = $arg->{basename} || 'dump';

  my ($dump, $error) = try {
    (YAML::Dump($value), undef);
  } catch {
    (undef, $_);
  };

  if (defined $dump) {
    my $ident = ref $value     ? (try { "$value" } catch { "<unknown>" })
              : defined $value ? $value
              :                  "(undef)";

    ($ident) = split /\n/, $ident;
    $ident = "<<unknown>>"
      unless defined $ident and length $ident and $ident =~ /\S/;

    return {
      filename => "$basename.yaml",
      mimetype => 'text/plain',
      body     => $dump,
      ident    => $ident,
    };
  } else {
    my $string = try { "$value" } catch { "value could not stringify: $_" };
    return {
      filename => "$basename.txt",
      mimetype => 'text/plain',
      body     => $string,
      ident    => "<error>",
    };
  }
}

1;
