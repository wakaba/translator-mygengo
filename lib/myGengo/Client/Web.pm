package myGengo::Client::Web;
use strict;
use warnings;

sub htescape ($) {
  my $s = $_[0];
  $s =~ s/&/&amp;/g;
  $s =~ s/\"/&quot;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  return $s;
} # htescape

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
              (htescape scalar localtime $_->updated),
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
        <h1>Job #%d</h1>
        <table>
          <tbody>
            <tr>
              <th>Source language
              <td>%s
            <tr>
              <th>Source text
              <td>%s
          <tbody>
            <tr>
              <th>Target language
              <td>%s
            <tr>
              <th>Target text
              <td>%s
          <tbody>
            <tr>
              <th>Status
              <td>%s
            <tr>
              <th>Updated
              <td>%s
          <tbody>
            <tr>
              <th>Data
              <td><pre>%s</pre>
        </table>
      },
          $job->job_id, $job->job_id,
          htescape $job->source_lang, htescape $job->source_body,
          htescape $job->target_lang, htescape $job->target_body,
          htescape $job->status,
          (htescape scalar localtime $job->updated),
          htescape Data::Dumper::Dumper ($job->data);
      $app->send_html ($html);
      $app->throw;
    }

  } elsif (@$path == 1 and $path->[0] eq 'syncjobs') {
    if (($http->request_auth->{auth_scheme} // '') ne 'basic') {
      $http->set_status (401);
      $http->set_response_auth
          ('basic', realm => 'myGengo API key and private key');
      $app->send_plain_text (401);
      $app->throw;
    }

    require myGengo::Client::MySQL;
    require Dongry::Database;
    require WebService::myGengo::Lite;
    
    my $ws = WebService::myGengo::Lite->new
        (api_key => $http->request_auth->{userid},
         private_key => $http->request_auth->{password});

    my $res = $ws->job_list;
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
    
    $app->send_plain_text ('done');
    $app->throw;
  }
  $app->throw_error (404);
} # process

1;
