package myGengo::Client::Object::JobCreatedEvent;
use strict;
use warnings;
use myGengo::Client::Object::JobEvent;
push our @ISA, qw(myGengo::Client::Object::JobEvent);

sub new_from_time ($) {
  return bless {timestamp => $_[1]}, $_[0];
} # new_from_time

sub type ($) {
  return 'job_created';
} # type

sub author_type ($) {
  return 'customer';
} # author_type

sub label ($) {
  return 'Created the job';
} # label

sub timestamp ($) {
  return $_[0]->{timestamp};
} # timestamp

1;
