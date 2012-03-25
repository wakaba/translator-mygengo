package myGengo::Client::Object::Comment;
use strict;
use warnings;

sub new_from_hashref ($$) {
  return bless $_[1], $_[0];
} # new_from_hashref

sub created ($) {
  return $_[0]->{ctime};
} # created

sub author_type ($) {
  return $_[0]->{author};
} # author_type

sub body ($) {
  return $_[0]->{body};
} # body

1;
