package Exception::Reporter::Role::Reporter;
use Moose::Role;
# ABSTRACT: a thing that can report exceptions

requires 'report_exception';

1;
