package myGengo::Client::Object::Revision;
use strict;
use warnings;
use myGengo::Client::Object::JobEvent;
push our @ISA, qw(myGengo::Client::Object::JobEvent);

sub new_from_hashref ($$) {
  return bless {data => $_[1]}, $_[0];
} # new_from_hashref

sub type ($) {
  return 'revision';
} # type

sub author_type ($) {
  return 'worker';
} # author_type

sub timestamp ($) {
  return $_[0]->{data}->{ctime};
} # timestamp

sub label ($) {
  return 'Revised';
} # label

sub comment_for_translator ($) {
  return $_[0]->{data}->{body_tgt};
} # comment_for_translator

1;
