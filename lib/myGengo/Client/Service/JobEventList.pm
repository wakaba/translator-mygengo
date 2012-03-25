package myGengo::Client::Service::JobEventList;
use strict;
use warnings;
use Dongry::Database;
use myGengo::Client::MySQL;
use myGengo::Client::Object::Job;

sub new_from_job_id ($$) {
  return bless {job_id => $_[1]}, $_[0];
} # new_from_job_id

sub db {
  return $_[0]->{db} ||= Dongry::Database->load ('mygengo');
} # db

sub job ($) {
  my $self = shift;
  return $self->{job} ||= do {
    my $row = $self->db->table ('job')->find ({id => $self->{job_id}});
    myGengo::Client::Object::Job->new_from_row ($row);
  };
} # job

sub event_list ($) {
  my $self = shift;

  require List::Ish;
  my $result = List::Ish->new;

  my $job = $self->job;
  my $job_id = $job->job_id;
  my $db = $self->db;

  {
    my $created = $job->created or last;
    
    require myGengo::Client::Object::JobCreatedEvent;
    $result->push
        (myGengo::Client::Object::JobCreatedEvent->new_from_time ($created));
  }

  {
    my $row = $db->table ('job_approval')->find ({job_id => $job_id})
        or last;
    
    require myGengo::Client::Object::JobApprovedEvent;
    $result->push
        (myGengo::Client::Object::JobApprovedEvent->new_from_row ($row));
  }

  {
    my $comments = $job->comments;
    my $cc_rows = $db->table ('customer_comment')->find_all
        ({job_id => $job_id});
    my $cc_rows_by_time = {map { $_->get ('created') => $_ } @$cc_rows};

    $comments->each (sub {
      my $comment = $_;
      my $cc_row = $comment->author_type eq 'customer'
          ? $cc_rows_by_time->{$comment->timestamp} : undef;
      $cc_row = undef if $cc_row and $cc_row->get ('body') ne $comment->body;
      if ($cc_row) {
        delete $cc_rows_by_time->{$comment->timestamp};
        $comment->set_row ($cc_row);
      }
    });
    $result->append ($comments);

    for (keys %$cc_rows_by_time) {
      my $cc_row = $cc_rows_by_time->{$_};
      
      require myGengo::Client::Object::Comment;
      $result->push (myGengo::Client::Object::Comment->new_from_row ($cc_row));
    }
  }

  $result = $result->sort (sub { $_[0]->timestamp <=> $_[1]->timestamp });
  
  return $result;
} # event_list

1;
