#!/usr/bin/env iced

{config} = require "./config"
SES = require 'amazon-ses'

##=======================================================================

class Burner
  
  constructor : ->
    id = config.amazon.ses.access_key_id
    key = config.amazon.ses.secret_access_key
    @_ses = new SES id, key

  #-----------------------------------------

  make_email_line : (o) -> "#{o.name} <#{o.email}>"
  
  #-----------------------------------------

  format_subject : (s) ->
    d = new Date()
    months = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul",
      "Aug", "Sep", "Oct", "Nov", "Dec" ]
    days = [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ]
    d_obj =
      m : months[d.getMonth()]
      d : d.getDate()
      y : d.getFullYear()
      w : days[d.getDay()]

    rxx = /(.*)%(w|d|y|m)(.*)/
    while (m = s.match rxx)
      m[2] = d_obj[m[2]]
      s = m[1..].join ''

    return s
      
  #-----------------------------------------

  run : ->
    cfg = config.email
    from = @make_email_line cfg.from
    to = [ @make_email_line cfg.to ]
    replyTo = [ @make_email_line cfg.reply ]
    subject = @format_subject cfg.subject
    body = { plain : "", html : "" } 
    rc = 0
    
    args = { replyTo, from, to, subject, body }
        
    console.log "+> Sending email to #{to} w/ subject '#{subject}'"

    if config.amazon.ses.simulate
      console.log "++> Simulating, but would have sent: #{JSON.stringify args}"
    else
      console.log "++> sending..."
      await @_ses.send args, defer err, res
      if err
        console.log "XX> Error in send: #{err}"
        rc = -1
      else
        console.log "oo> Sent w/ ID=#{res?.SendEmailResult?.MessageId}"
    
   
    process.exit rc
  
##=======================================================================

b = new Burner()
b.run()

##=======================================================================
