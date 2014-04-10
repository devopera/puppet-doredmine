class doredmine::monitor (

  # class arguments
  # ---------------
  # setup defaults
  
  $port = 80,
  $site_name = 'Redmine',
  
  # end of class arguments
  # ----------------------
  # begin class

) {

  # check content of http response
  @nagios::service { "http_content:${port}-doredmine-${::fqdn}":
    # no DNS, so need to refer to machine by external IP address
    check_command => "check_http_port_url_content!${::ipaddress}!${port}!/!'>${site_name}<'",
  }

}


