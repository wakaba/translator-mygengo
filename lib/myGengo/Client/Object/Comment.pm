package myGengo::Client::Object::Comment;
use strict;
use warnings;
use myGengo::Client::Object::JobEvent;
push our @ISA, qw(myGengo::Client::Object::JobEvent);

sub new_from_hashref ($$) {
  return bless {data => $_[1]}, $_[0];
} # new_from_hashref

sub new_from_row ($$) {
  return bless {row => $_[1]}, $_[0];
} # new_from_row

sub set_row ($$) {
  $_[0]->{row} = $_[1];
}

sub row ($) {
  return $_[0]->{row};
} # row

sub type ($) {
  return 'comment';
} # type

sub client_record_id ($) {
  my $row = $_[0]->row or return undef;
  return $row->get ('id');
} # client_record_id

sub not_found_at_server ($) {
  return not $_[0]->{data};
} # not_found_at_server

sub author_id ($) {
  my $row = $_[0]->row;
  if ($row) {
    return $row->get ('author_id');
  } else {
    return undef;
  }
} # author_id

sub author_type ($) {
  if ($_[0]->{data}) {
    return $_[0]->{data}->{author};
  } elsif ($_[0]->row) {
    return 'customer';
  }
} # author_type

sub timestamp ($) {
  if ($_[0]->{data}) {
    return $_[0]->{data}->{ctime};
  } elsif ($_[0]->row) {
    return $_[0]->row->get ('created');
  } else {
    return undef;
  }
} # timestamp

sub label ($) {
  return 'Commented';
} # label

sub comment_for_translator ($) {
  return undef if $_[0]->author_type eq 'worker';
  if ($_[0]->{data}) {
    return $_[0]->{data}->{body};
  } elsif ($_[0]->row) {
    return $_[0]->row->get ('body');
  } else {
    return undef;
  }
} # comment_for_translator

sub comment_for_customer ($) {
  return undef if $_[0]->author_type eq 'customer';
  if ($_[0]->{data}) {
    return $_[0]->{data}->{body};
  } elsif ($_[0]->row) {
    return $_[0]->row->get ('body');
  } else {
    return undef;
  }
} # comment_for_customer

1;
