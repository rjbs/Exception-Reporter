use strict;
use warnings;
package Exception::Reporter::Dumper::YAML;
use parent 'Exception::Reporter::Dumper';
# ABSTRACT: a dumper to turn any scalar value into a plaintext YAML record

use Try::Tiny;
use YAML::XS ();

sub _ident_from {
  my ($self, $str, $x) = @_;

  $str =~ s/\A\n+//;
  ($str) = split /\n/, $str;

  unless (defined $str and length $str and $str =~ /\S/) {
    $str = sprintf "<<unknown%s>>", $x ? ' ($x)' : '';
  }

  return $str;
}

sub dump {
  my ($self, $value, $arg) = @_;
  my $basename = $arg->{basename} || 'dump';

  my ($dump, $error) = try {
    (YAML::XS::Dump($value), undef);
  } catch {
    (undef, $_);
  };

  if (defined $dump) {
    my $ident = ref $value     ? (try { "$value" } catch { "<unknown>" })
              : defined $value ? "$value" # quotes in case of glob, vstr, etc.
              :                  "(undef)";

    $ident = $self->_ident_from($ident);

    return {
      filename => "$basename.yaml",
      mimetype => 'text/plain',
      body     => $dump,
      ident    => $ident,
    };
  } else {
    my $string = try { "$value" } catch { "value could not stringify: $_" };
    my $ident  = $self->_ident_from($string);

    return {
      filename => "$basename.txt",
      mimetype => 'text/plain',
      body     => <<EOB,
__DATA__
$string
__YAML_ERROR__
$error
EOB
      ident    => $ident,
    };
  }
}

1;
