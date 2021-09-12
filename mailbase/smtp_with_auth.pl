#!/usr/bin/perl -w

use strict;
use warnings;
use bytes;

use DBI;
use DBD::mysql;
#use Net::Server::Mail::SMTP;
use Net::Server::Mail::ESMTP;
use Net::Server::Mail::ESMTP::STARTTLS;
use IO::Socket ;
use Socket qw( sockaddr_family sockaddr_in sockaddr_in6 inet_ntop AF_INET);
use File::Slurp;
#use IO::Socket::SSL qw(SSL_VERIFY_NONE);

my $authenticated_user;

my $server;

# if ACCEPT_AUTH is set to 'yes', simulate being a corporate server by listening on 587 and allowing logins (creds in db) 
if($ENV{'ACCEPT_AUTH'} =~ m/yes/i){ $server = new IO::Socket::INET Listen => 1, LocalPort => 587; }
else{$server = new IO::Socket::INET Listen => 1, LocalPort => 25;}

print "Server started\n";

my $conn; 

while($conn = $server->accept)
{

 my $clientip = $conn->peerhost();
 print $clientip . "\n";
 # too lazy to reap my kids
 $SIG{'CHLD'} = "IGNORE";
 my $kidpid = fork();
 if(!$kidpid)
 {

  # grr ipv6 
  # means I can't just do this
  # $peerhost = inet_ntoa($peerhost);
  # instead the next 6 lines taken from http://www.perlmonks.org/?node_id=948946 might do the trick

  #my $sockaddr = $conn->sockname(); #getsockaddr($conn);     # Or: $sock->sockname()
  #my $fam = sockaddr_family($sockaddr);
  #my $addr_n = $fam == AF_INET
  #  ? (sockaddr_in($sockaddr))[1]
  #  : (sockaddr_in6($sockaddr))[1];
  #$fromip = inet_ntop($fam, $addr_n);

  print "Accepted connection\n";
  #$smtp = new Net::Server::Mail::ESMTP socket => $conn;
  
  my $smtp = new Net::Server::Mail::ESMTP(
   socket => $conn,
   Timeout => '600',
   Debug => 1,
   error_sleep_time => 600,
   idle_timeout => 600,
   ssl_config => {
	 		SSL_cert_file => '/mail/mail.crt',
	  	SSL_key_file => '/mail/mail.key',
      }
  );


  $smtp->{banner_string} = 'Shall we play a game? WOPR Ready';
  # perhaps you'd like to set the above to some specific server that's currently of interest
  #'Microsoft Exchange Server Ready';

  # activate STARTTLS extension
  $smtp->register('Net::Server::Mail::ESMTP::STARTTLS');
  $smtp->set_callback(STARTTLS => \&tls_started);
  
  if($ENV{'ACCEPT_AUTH'} =~ m/yes/i){ 
    print " activate AUTH extension\n";
    $smtp->register('Net::Server::Mail::ESMTP::AUTH');
   
    print " adding AUTH handler\n";
    $smtp->set_callback(AUTH => \&validate_auth);
  }

  $smtp->register('Net::Server::Mail::ESMTP::8BITMIME');
  $smtp->register('Net::Server::Mail::ESMTP::PIPELINING');
  
  print "Setting validating recip callback\n";
  $smtp->set_callback(RCPT => \&validate_recipient);
   
  print "Setting queue_message callback\n";
  $smtp->set_callback(DATA => \&queue_message);
  
  print "Doing process()\n";
  $smtp->process();
  
  print "Doing close()\n";
  $conn->close();
  
  print "$$ exiting\n";
  exit;
 }

 print "Child process $kidpid running\n";
 
}

sub validate_recipient
{
  print "Validate recipient\n";
  my($session, $recipient) = @_;
  # do nothing for now
  return(1);
}

sub queue_message
{
  my($session, $data) = @_;

  my $sender = $session->get_sender();
  my @recipients = $session->get_recipients();

  print "Inspecting message:\nSender: $sender\nRecipient: $recipients[0]\n";

  # foreach recipient: insert messageid -> recipient
  my @validated_recipients = ();

  # we could turn this into a message alias config file or db table instead, 
  # but for now this is ok

  foreach my $rcptto (@recipients)
  {

    #$rcptto =~ s/\@.*//;
    $rcptto =~ s/^<//;
    $rcptto =~ s/>$//;

    print "Evaluating $rcptto\n";

    # blacklists
    if($rcptto =~ m/keywords_were_sick_of_seeing/i) {
      print "Blacklist $rcptto\n";
      next;
    }

    # use this to rewrite things to a specific mailbox, if you wish to view with a client like
    # thunderbird / mail / outlook
    # (requires separate pop3 or imap layer, or some other means of providing access to the client)
    $rcptto =~ s/some_general_pattern.*\@somedomain.com/real_user\@real_domain.com/;

    $rcptto = lc($rcptto);
    print "... after alias processing: $rcptto\n";


    # check if the rewritten rcptto matches our catchall box
    # or if we're letting this logged in user send
    if ($rcptto eq 'real_user@real_domain.com' 
    or $rcptto eq 'some_other_user@real_domain.com'
    or (defined($authenticated_user) and length($authenticated_user))){
      push(@validated_recipients, $rcptto);
    }
  }

  if($#validated_recipients >= 0) {
    print "Found some valid recipients:" . join(" ", @validated_recipients) . "\n";

    print "queue message\n";
    my $dbh = DBI->connect('dbi:mysql:email', 'root', $ENV{'MARIADB_ROOT_PASSWORD'});
    $dbh->{max_allowed_packet}=1000000000;
    $dbh->{mysql_auto_reconnect} = 1;
    my $sthmsg = $dbh->prepare("insert into messages (msg, mailfrom) values (?,?)");
    my $sthrcpt = $dbh->prepare("insert into rcptto (rcptto, msgid, sender_auth) values (?,?,?)");


    # insert new record of message, data, from into mysql messages table, get messageid
    $sthmsg->execute($$data, $sender);
    my $msgid = $dbh->{ q{mysql_insertid}};
    print "Saved message from $sender with id $msgid\n";

    foreach my $valid_rcptto (@validated_recipients){
      $sthrcpt->execute($valid_rcptto, $msgid, $authenticated_user);
      print "  Flagged $msgid as being to $valid_rcptto -- authuser: $authenticated_user\n";      
    }

  }
  else {
    print "No valid recipient\n";
    return(0, 554, 'Error: no valid recipients');
  }

  return(1, 250, "message queued 10101");
}

sub tls_started
{
  my ($session) = @_;

  print "Doing STARTTLS, allowing authentication now\n";
  
}

sub validate_auth
{
  my ($session, $user, $pass) = @_;
  
  warn "Trying to authenticate $user / $pass\n";
  my $dbh = DBI->connect('dbi:mysql:email', 'root', $ENV{'MARIADB_ROOT_PASSWORD'});
  my $sthauth = $dbh->prepare("select mailuser from mailusers where mailuser = ? and mailpass = ?");
  
  $sthauth->execute($user, $pass);
  my $ref_auth = $sthauth->fetchrow_hashref ();
  if($user eq $ref_auth->{mailuser})
  {
    warn "Auth Success\n";
    $authenticated_user = $user;
    return 1;
  }
  else
  {
    warn "Failed auth\n";
    return 0;
  }


}

