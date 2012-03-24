package myGengo::Client::Web;
use strict;
use warnings;

sub htescape ($) {
  my $s = $_[0];
  return '' unless defined $s;
  $s =~ s/&/&amp;/g;
  $s =~ s/\"/&quot;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  return $s;
} # htescape

sub price ($) {
  my $c = shift;
  return '$' . $c;
} # price

sub timestamp ($) {
  my $t = shift;
  return scalar (gmtime $t) . ' UTC';
} # timestamp

sub time_amount ($) {
  my $s = shift;
  if ($s <= 0) {
    return $s . 's';
  }

  my @v;
  if ($s % 60) {
    unshift @v, ($s % 60) . ' s';
  }
  $s = int ($s / 60);
  if ($s % 60) {
    unshift @v, ($s % 60) . ' min';
  }
  $s = int ($s / 60);
  if ($s) {
    unshift @v, $s . ' h';
  }
  return join ' ', @v;
} # time_amount

sub boolean ($) {
  return $_[0] ? 'Yes' : 'No';
} # boolean

sub process ($$) {
  my $app = $_[1];
  my $http = $app->http;
  
  my $path = $app->path_segments;
  if (@$path == 2 and $path->[0] eq 'job') {
    if ($path->[1] eq '' or $path->[1] eq 'index.json') {
      require Dongry::Database;
      require myGengo::Client::MySQL;
      require myGengo::Client::Object::Job;

      my $db = Dongry::Database->load ('mygengo');
      my $jobs = $db->query
          (table_name => 'job',
           where => {
               id => {-ne => undef},
           },
           order => [updated => 'desc'],
           item_list_filter => sub {
             return $_[1]->map (sub {
               return myGengo::Client::Object::Job->new_from_row ($_);
             });
           })->find_all (offset => 0, limit => 100);

      if ($path->[1] eq 'index.json') {
        $app->send_json ($jobs->map (sub { $_->as_jsonable }));
      } else {
        my $job_trs  = join '', map {
          sprintf q{
            <tr>
              <th title="Updated: %s"><a href="%s">%d</a>
              <td>%s
              <td>%s
              <td>%s
              <td>%s
              <td>%s
          },
              htescape timestamp $_->updated,
              htescape $_->path,
              $_->job_id,
              htescape $_->source_lang, htescape $_->source_body,
              htescape $_->target_lang, htescape $_->target_body,
              htescape $_->status;
        } @$jobs;

        my $html = sprintf q{
          <!DOCTYPE HTML>
          <html lang=en>
          <title>Jobs</title>
          <link rel=stylesheet href="/css/mygengo-client">
          <h1>Jobs</h1>
          <table>
            <thead>
              <tr>
                <th rowspan=2><abbr title="Job ID">#</abbr>
                <th colspan=2>
                  Source
                <th colspan=2>
                  Target
                <th rowspan=2>Status
              <tr>
                <th><abbr title=Language>Lang</abbr>
                <th>Text
                <th><abbr title=Language>Lang</abbr>
                <th>Text
            <tbody>
              %s
          </table>

          <section>
            <h2>Actions</h2>

            <form action=/job/sync method=POST>
              <button type=submit>
                Sync recent jobs
              </button>
            </form>
          </section>
        }, $job_trs;
        $app->send_html ($html);
      }
      $app->throw;
    } elsif ($path->[1] =~ /\A[0-9]+\z/) {
      require Dongry::Database;
      require myGengo::Client::MySQL;
      require myGengo::Client::Object::Job;
      require Data::Dumper;

      my $db = Dongry::Database->load ('mygengo');
      my $row = $db->table ('job')->find ({id => $path->[1]});
      $app->throw_code (404) unless $row;
      my $job = myGengo::Client::Object::Job->new_from_row ($row);
      
      my $html = sprintf q{ 
        <!DOCTYPE HTML>
        <title>Job #%d</title>
        <link rel=stylesheet href="/css/mygengo-client">
        <h1>Job #%d</h1>
        <table>
          <tbody>
            <tr>
              <th rowspan=3>Source
              <th>Language
              <td>%s
            <tr>
              <th>Text
              <td>%s
            <tr>
              <th>Unit count
              <td>%d
          <tbody>
            <tr>
              <th rowspan=3>Target
              <th>Language
              <td>%s
            <tr>
              <th>Text
              <td>%s
            <tr>
              <th>Is machine-translation
              <td>%s
          <tbody>
            <tr>
              <th rowspan=2>Status
              <th>Current
              <td>%s
            <tr>
              <th>Auto-approve
              <td>%s
            <tr>
              <th colspan=2>Updated
              <td>%s
          <tbody>
            <tr>
              <th colspan=2>Quality level
              <td>%s
            <tr>
              <th colspan=2>Credit price
              <td>%s
            <tr>
              <th colspan=2>Estimated time
              <td>%s
        </table>

        <section>
          <h2>Job data dump</h2>
          <pre>%s</pre>
        </section>
      },
          $job->job_id, $job->job_id,
          htescape $job->source_lang, htescape $job->source_body,
          htescape $job->unit_count,
          htescape $job->target_lang, htescape $job->target_body,
          htescape boolean $job->target_is_machine_translation,
          htescape $job->status,
          htescape boolean $job->auto_approve,
          htescape timestamp $job->updated,
          htescape $job->tier,
          htescape price $job->credits,
          htescape time_amount $job->eta,
          htescape Data::Dumper::Dumper ($job->data);
      $app->send_html ($html);
      $app->throw;
    } elsif ($path->[1] eq 'sync') {
      if (($http->request_auth->{auth_scheme} // '') ne 'basic') {
        $http->set_status (401);
        $http->set_response_auth
            ('basic', realm => 'myGengo API key and private key');
        $app->send_plain_text (401);
        $app->throw;
      }
      $app->requires_request_method ({POST => 1});
      
      require myGengo::Client::MySQL;
      require Dongry::Database;
      require WebService::myGengo::Lite;
      
      my $ws = WebService::myGengo::Lite->new
          (api_key => $http->request_auth->{userid},
           private_key => $http->request_auth->{password});
      
      my $res = $ws->job_list (count => 100);
      $app->throw_error (400) if $res->is_error;
      
      $res = $ws->jobs_get ([map { $_->{job_id} } @{$res->data}]);
      $app->throw_error (400) if $res->is_error;
      
      my $db = Dongry::Database->load ('mygengo');
      
      for my $job (@{$res->jobs}) {
        $db->table ('job')->insert ([{
          id => $job->{job_id},
          source_lang => $job->{source}->{lang} // '',
          source_body => $job->{source}->{body} // '',
          target_lang => $job->{target}->{lang} // '',
          target_body => $job->{target}->{body} // '',
          status => $job->{status},
          data => {%$job},
          updated => time,
        }], duplicate => 'replace');
      }
      
      $app->throw_redirect ('/job/');
    }
  } elsif (@$path == 2 and $path->[0] eq 'css') {
    if ($path->[1] eq 'mygengo-client') {
      $http->set_response_header ('Content-Type' => 'text/css; charset=utf-8');
      $http->send_response_body_as_text (q{
        h1, h2 {
          background-color: #F9F9F9;
          color: black;
          padding: 0.2em 0.4em;
        }

        h1 {
          font-size: 150%;
        }
        h2 {
          font-size: 130%;
        }

        section {
          display: block;
          margin: 1em;
        }

        table {
          width: 100%;
        }

        th {
          background-color: #F9F9F9;
          color: black;
        }
        th, td {
          padding: 0.2em;
        }
      });
      $app->throw;
    }
  }
  $app->throw_error (404);
} # process

1;
