use strict;
use warnings;
package Exception::Reporter::Types;

use Moose::Util::TypeConstraints;

use Exception::Reporter::Role::Reporter;
use Exception::Reporter::Role::Summarizer;

subtype 'Exception::Reporter::Types::Summarizers',
  as 'ArrayRef[Exception::Reporter::Role::Summarizer]',
  where { @$_ > 0 };

subtype 'Exception::Reporter::Types::Reporters',
  as 'ArrayRef[Exception::Reporter::Role::Reporter]',
  where { @$_ > 0 };

1;
