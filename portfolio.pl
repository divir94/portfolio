#!/usr/bin/perl -w

# The overall theory of operation of this script is as follows
#
# 1. The inputs are form parameters, if any, and a session cookie, if any. 
# 2. The session cookie contains the login credentials (User/Password).
# 3. The parameters depend on the form, but all forms have the following three
#    special parameters:
#
#         act      =  form  <the form in question> (form=base if it doesn't exist)
#         run      =  0 Or 1 <whether to run the form or not> (=0 if it doesn't exist)
#
# 4. The script then generates relevant html based on act, run, and other 
#    parameters that are form-dependent
# 5. The script also sends back a new session cookie (allowing for logout functionality)
#

use strict;
use CGI qw(:standard);
use CGI::Carp qw/fatalsToBrowser/;
use DBI;
use Time::ParseDate;
use stock_data_access;


my $dbuser = "dgg340";
my $dbpasswd = "dgg340";

#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again. 
#
# "PortfolioSession"=>"user/password"
#

#
my $cookiename = "PortfolioSession";
#

#
# Get the session input cookies, if any
#
my $inputcookiecontent = cookie($cookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $deletecookie = 0;
my $user = undef;
my $password = undef;
my $logincomplain = 0;

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;


######################################################################
#
# Set action
#
######################################################################

if (defined(param("act"))) { 
  $action = param("act");
  if (defined(param("run"))) { 
    $run = param("run");
  } else {
    $run = 0;
  }
} else {
  $action = "base";
  $run = 1;
}

######################################################################
#
# Cookies
#
######################################################################

if (defined($inputcookiecontent)) { 
  # Has cookie, let's decode it
  ($user,$password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;
} else {
  # No cookie, treat as anonymous user
  ($user,$password) = ("anon","anon");
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") { 
  if ($run) { 
    #
    # Login attempt
    #
    # Ignore any input cookie.  Just validate user and
    # generate the right output cookie, if any.
    #
    ($user,$password) = (param('user'),param('password'));
    if (ValidUser($user, $password)) { 
      # if the user's info is OK, then give him a cookie
      # that contains his username and password 
      # the cookie will expire in one hour, forcing him to log in again
      # after one hour of inactivity.
      # Also, land him in the base query screen
      $outputcookiecontent=join("/",$user,$password);
      $action = "base";
      $run = 1;
    } else {
      # uh oh.  Bogus login attempt.  Make him try again.
      # don't give him a cookie
      $logincomplain = 1;
      $action = "login";
      $run = 0;
    }
  } else {
    #
    # Just a login screen request, but we should toss out any cookie
    # we were given
    #
    undef $inputcookiecontent;
    ($user,$password)=("anon", "anon");
  }
} 

my @outputcookies;

#
# OK, so now we have user/password and we *may* have an output cookie. 
# If we have a cookie, we'll send it right back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) { 
  my $cookie = cookie(-name=>$cookiename, -value=>$outputcookiecontent, -expires=>($deletecookie ? '-1h' : '+1h'));
  push @outputcookies, $cookie;
} 


######################################################################
#
# Base page
#
######################################################################

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
print start_html('Portfolio Manager').
	"<html>".
	"<head>".
	"<title>Portfolio Manager</title>".
	"</head>".
	"<body>".
	"<center>";

#
# This tells the web browser to render the page in the style
# defined in the css file
#
#print "<style type=\"text/css\">\n\@import \"portfolio.css\";\n</style>\n";
  


######################################################################
#
# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code. So, here we only show the form if needed.
# 
######################################################################

if ($action eq "login") {
  if ($logincomplain) { 
    print "Login failed. Please try again.<p>";
  } 
  if ($logincomplain or !$run) {
    print start_form(-name=>'Login'),
    	h2('Login to portfolio'),
  	  	"Name:", textfield(-name=>'user'), p,
  	  	"Password:", password_field(-name=>'password'), p,
  	  	hidden(-name=>'act', default=>['login']),
  	  	hidden(-name=>'run', default=>['1']),
  		submit,
		end_form;
  }
}

#
# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
  $deletecookie = 1;
  $action = "base";
  $user = "anon";
  $password = "anon";
  $run = 1;
}


######################################################################
#
# BASE
#
# The base action presents the overall page to the browser.
# This is the "document" that the JavaScript manipulates.
#
######################################################################

if ($action eq "base") { 
  print "This is the base action.\n";

  #
  # User modes
  #
  if ($user eq "anon") {
    print "<p>You are anonymous, but you can also <a href=\"portfolio.pl?act=login\">login</a>.</p>";
  } else {
    print "<p>You are logged in as $user.</p>";
    print "<p><a href=\"portfolio.pl?act=logout&run=1\">Logout</a></p>";
  }
}


print "</body></center>" . end_html;


######################################################################
#
# HELPER FUNCTIONS
#
######################################################################

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
  my ($user, $password) = @_;
  my @col;
  eval {@col = ExecStockSQL("COL", "SELECT count(*) from PF_USERS where name = ? and password = ?", $user, $password);};
  if ($@) { 
    return 0;
  } else {
    return $col[0] > 0;
  }
}