
srv_base = require "../lib/srv_base"
{config} = require "./config"
SES = require 'amazon-ses'

##=======================================================================

class Email

  constructor : (fields) ->
    for k,v of fields
      @[k] = v
    @amzn_ses_id = null unless fields.amzn_ses_id?

  #-----------------------------------------

  send : (ses, cb) ->
    args =
      from : @from_line
      to : [ @email ]
      subject : @subject
      body :
        plain : @plain_body
        html : @html_body
    console.log "+> Sending email to #{@email} w/ subject '#{args.subject}'"
    if Config.amazon.ses.simulate
      err = null
      res = { SendEmailResult : { MessageId : id.generate id.MAIL } }
      console.log "++> Simulating, but would have sent: #{JSON.stringify args}"
    else
      await ses.send args, defer err, res

    ok = true
    @status = constants.mail.spool.SENT

    if err
      ok = false
      @_err = err
      @status = constants.mail.spool.SEND_ERROR
      console.log "Error sending to #{args.from}: #{err}"
    else if (i = res?.SendEmailResult?.MessageId)
      @amzn_ses_id = i

    await @mark defer()
    cb @status

  #-----------------------------------------

  mark_bounce : (cb) ->
    q = """UPDATE mail_spool
           SET status=?,
               delivery_status=?,
               bounce_type=?
           WHERE amzn_ses_id=?"""

    C = constants.mail.spool

    @status = if @bounce_type is "Permanent" then C.PERM_DELIVERY_ERROR
    else C.TEMP_DELIVERY_ERROR

    args = [ @status, @delivery_status, @bounce_type, @amzn_ses_id ]
    await db.get_client().query q, args, defer err
    ok = true
    if err
      ok = false
      console.log "Error marking bounce: #{err}"

    q = 'UPDATE user_emails SET last_delivery_status=? WHERE email=?'
    args = [ @status, @email ]
    await db.get_client().query q, args, defer err
    if err
      console.log "Error updating status of #{email} to {#status}: #{err}"

    cb ok

  #-----------------------------------------

  mark : (cb) ->
    args = [ @status ]
    if @amzn_ses_id
      args.push @amzn_ses_id
      ses_id_set = ", amzn_ses_id=?, sent_at=NOW()"
    else
      ses_id_set = ""
    args.push @mid
    q = """UPDATE mail_spool
           SET status=? #{ses_id_set}
           WHERE mid=CONV(?,16,10)"""
    await db.get_client().query q, args, defer err
    if err
      console.log "Error in update for mid=#{mid}: #{err}"
    cb()

##=======================================================================

class Burner
  
  constructor : ->
    id = config.amazon.access_key_id
    key = config.amazon.secret_access_key
    @_ses = new SES id, key

  #-----------------------------------------

  run : ->
    process.exit 0

##=======================================================================

b = new Burner()
b.run()

##=======================================================================
