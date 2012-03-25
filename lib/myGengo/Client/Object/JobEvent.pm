package myGengo::Client::Object::JobEvent;
use strict;
use warnings;

sub client_record_id ($) {
  return undef;
} # client_record_id

sub not_found_at_server ($) {
  return 0;
} # not_found_at_server

sub author_id ($) {
  return undef;
} # author_id

sub author ($) {
  return $_[0]->{author};
} # author

sub set_author ($$) {
  $_[0]->{author} = $_[1];
} # set_author

sub comment_for_translator ($) {
  return undef;
} # comment_for_translator

sub comment_for_mygengo ($) {
  return undef;
} # comment_for_mygengo

sub comment_is_public ($) {
  return undef;
} # comment_is_public

sub rating ($) {
  return undef;
} # rating

sub reason ($) {
  return undef;
} # reason

sub follow_up ($) {
  return undef;
} # follow_up

1;
