use strict;
use warnings;
package Exception::Reporter::Dumper::YAML;
use parent 'Exception::Reporter::Dumper';
# ABSTRACT: a dumper to turn any scalar value into a plaintext YAML record

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
              : defined $value ? "$value" # quotes in case of glob, vstr, etc.
              :                  "(undef)";

    $ident =~ s/\A\n*([^\n]+)(?:\n|$).*/$1/;
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
