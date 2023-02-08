#!/usr/bin/ruby
# ==============================================================================
# DESC: send sms to aspsms gateway
# $Revision: 1.3 $
# $RCSfile: sms.rb,v $
# $Author: Sandrello $
#
# synopsis: echo 'test' | sms.rb <recipient..>
#  
# ==============================================================================
# Copyright (c) Chris Ruettimann <chris@bitbull.ch>

# This software is licensed to you under the GNU General Public License.
# There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
# along with this software; if not, see
# http://www.gnu.org/licenses/gpl.txt


require 'rexml/document'
require 'yaml'
require 'getoptlong'
require 'socket'
require 'net/http'

CONF='/etc/sms.conf'
USAGE = "
Usage: sms [options] [recipient..]
    -h|--help        : this short description
    -C|--credits     : show credits
    -D|--debug       : show debugging messages
    -c|--config-file : set configuration file (default #{CONF})
    -f|--from        : set sender (originator)
    recipient..
"


class Sms
  def initialize
    @cfg_file = CONF
    @check_credits = false
    @do_debug = false
    get_parms
    @cfg = YAML.load_file(@cfg_file)
    @text = Array.new
    @from =  @cfg['origin'] if @from.nil?
  end
  
  def run
    asp = Aspsms.new(@from, @cfg['user'], @cfg['password'], @cfg['gateway'], @cfg['port'])
    asp.debug(@do_debug)
    if @check_credits
      asp.check_credits
      puts asp.get_credits
    else
      $stdin.each {|l| @text << l.chomp}
      asp.send(@recipient, @text)
      c = asp.get_credits
      if c <= @cfg['credit_limit']
	text = 'credits out of limit: '+c.to_s+' <= '+@cfg['credit_limit'].to_s
        if @cfg['creditor'].nil?
	  puts text
	else
	  text = 'credits out of limit: '+c.to_s+' <= '+@cfg['credit_limit'].to_s
	  asp.send(@cfg['creditor'], @text)
	end
      end
    end
    puts
  end

  def get_parms
    opts = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--credits', '-C', GetoptLong::NO_ARGUMENT ],
      [ '--debug', '-D', GetoptLong::NO_ARGUMENT ],
      [ '--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
      [ '--from', '-f', GetoptLong::REQUIRED_ARGUMENT ]
    )

    opts.each do |opt, arg|
      case opt
        when '--help'
          puts USAGE
          exit 0
        when '--credits'
          @check_credits = true
        when '--debug'
          @do_debug = true
        when '--config'
          @cfg_file = arg
        when '--from'
          @from = arg
      end
    end

    if !@check_credits and ARGV.length < 1
      puts "Missing recipient argument (try --help)"
      exit 0
    end

    @recipient = ARGV
  end
  
end


class Aspsms
  include REXML

  def initialize(from, user, password, gateway, port)
    @from = from
    @user = user
    @password = password
    @gateway = gateway
    @port = port
  end

  def send(to, text)
    init_doc
    r = Element.new('Recipient')
    to.each do |t|
      r.elements.add(Element.new('PhoneNumber').add_text(t))
    end
    @e.elements.add(r)
    m = Element.new('MessageData')
    text.each do |t|
      m.add_text(t + "\n")
    end
    @e.elements.add(m)
    @e.elements.add(Element.new('Action').add_text('SendTextSMS'))
    @doc << @e
    send_request
    if check_response
      check_credits
    end
  end

  def check_credits
    init_doc
    @e.elements.add(Element.new('Action').add_text('ShowCredits'))
    @doc << @e
    send_request
    check_response
    get_credits
  end

  def debug(enable)
    @do_debug = enable
  end

  def error_desc
    @error_desc
  end

  def error_code
    case @error_code
      when 1
        return 0
      else
        return @error_code
    end
  end

  def get_credits
    @credits.to_i
  end

  def debug=(do_debug)
    @do_debug = do_debug
  end

  def debug?
    @do_debug
  end

  private

  def send_request
    @resp = Array.new
    gws = @gateway.clone
    gw = gws.shift
    doc = ''
    @doc.write(doc)

    begin
      http = Net::HTTP.new(gw, @port)
      http.set_debug_output($stderr) if debug?
      http.start {|session|
        session.post('/xmlsvr.asp', doc) {|r| @resp << r}
      }
    rescue
      puts('error: ', caller[1..-1]) if debug?
      gw = gws.shift
      retry unless gw.nil?
    end
  end

  def check_response
    doc = REXML::Document.new(@resp.join)
    root = doc.root
    root.each_element('*') do |elem|
      case elem.name
	when 'ErrorCode'
	  @error_code = elem.text
	when 'ErrorDescription'
	  @error_desc = elem.text
	when 'Credits'
	  @credits = elem.text.chomp
	else
	  @asp_resp = elem.text
      end
    end
    if @error_desc == 'Ok'
      return true
    else
      return false
    end
  end

  def init_doc
    @doc = Document.new('<?xml version="1.0" encoding="ISO-8859-1"?>')
    #@doc << XMLDecl.default
    @e = Element.new('aspsms')
    @e.elements.add(Element.new('Userkey').add_text(@user))
    @e.elements.add(Element.new('Password').add_text(@password))
    @e.elements.add(Element.new('Originator').add_text(@from))
  end

end

s = Sms.new
s.run


# vim:ai:sw=2
################################################################################
# $Log: sms.rb,v $
# Revision 1.3  2012/06/10 19:18:49  chris
# auto backup
#
# Revision 1.2  2010/02/15 18:49:11  chris
# clean up
#
# Revision 1.1  2010/01/17 20:40:18  chris
# Initial revision
#
